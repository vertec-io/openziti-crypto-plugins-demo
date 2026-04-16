// NOT FOR PRODUCTION USE.
//
// This is an educational reference plugin demonstrating how to register an
// alternate cipher via the OpenZiti secretstream hook API. It wraps Go's
// standard-library AES-256-GCM implementation. A production plugin would
// replace the crypto/aes + crypto/cipher calls with operations inside a
// certified cryptographic module.

package aesgcm

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/binary"
	"fmt"
	"os"

	"github.com/openziti/secretstream"
)

// CipherAES256GCM is the on-the-wire identifier for AES-256-GCM.
// CipherID 1 is reserved for the built-in ChaCha20-Poly1305.
const CipherAES256GCM secretstream.CipherID = 2

const (
	keySize   = 32 // AES-256
	nonceSize = 12 // GCM standard nonce
)

func init() {
	if err := secretstream.RegisterDefault(&provider{}); err != nil {
		fmt.Fprintf(os.Stderr, "aesgcm-reference-plugin: registration failed: %v\n", err)
	}
}

// provider implements secretstream.CryptoProvider for AES-256-GCM using
// only Go standard-library primitives.
type provider struct{}

func (*provider) Name() string                       { return "aes-256-gcm-reference" }
func (*provider) Ciphers() []secretstream.CipherID   { return []secretstream.CipherID{CipherAES256GCM} }
func (*provider) WireVersion() uint8                 { return 1 }
func (*provider) PreferencesBytes() []byte           { return []byte{byte(CipherAES256GCM)} }

func (p *provider) NegotiateCipherAsServer(peerPrefs []secretstream.CipherID) (secretstream.CipherID, error) {
	if len(peerPrefs) == 0 {
		// Empty peerPrefs: the peer did not advertise preferences
		// (legacy peer or router did not forward response headers).
		// Return our default cipher. This is correct when both
		// endpoints load the same plugin — both independently pick
		// AES-256-GCM. Against a stock peer this causes a wire
		// mismatch; a production plugin would support both ciphers.
		return CipherAES256GCM, nil
	}
	for _, id := range peerPrefs {
		if id == CipherAES256GCM {
			return CipherAES256GCM, nil
		}
	}
	return 0, secretstream.ErrCipherRejected
}

func (p *provider) NegotiateCipherAsClient(peerPrefs []secretstream.CipherID) (secretstream.CipherID, error) {
	return p.NegotiateCipherAsServer(peerPrefs)
}

func (*provider) NewEncryptor(c secretstream.CipherID, key []byte) (secretstream.Encryptor, []byte, error) {
	if c != CipherAES256GCM {
		return nil, nil, secretstream.ErrCipherRejected
	}
	gcm, err := newGCM(key)
	if err != nil {
		return nil, nil, err
	}
	header := make([]byte, nonceSize)
	if _, err := rand.Read(header); err != nil {
		return nil, nil, err
	}
	var nonce [nonceSize]byte
	copy(nonce[:], header)
	return &encryptor{gcm: gcm, nonce: nonce}, header, nil
}

func (*provider) NewDecryptorFromHeader(header, key []byte) (secretstream.Decryptor, secretstream.CipherID, error) {
	if len(header) != nonceSize {
		return nil, 0, secretstream.ErrHeaderMalformed
	}
	gcm, err := newGCM(key)
	if err != nil {
		return nil, 0, err
	}
	var nonce [nonceSize]byte
	copy(nonce[:], header)
	return &decryptor{gcm: gcm, nonce: nonce}, CipherAES256GCM, nil
}

func newGCM(key []byte) (cipher.AEAD, error) {
	if len(key) != keySize {
		return nil, fmt.Errorf("aesgcm: key must be %d bytes, got %d", keySize, len(key))
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	return cipher.NewGCM(block)
}

// encryptor seals each message with AES-256-GCM. The tag byte is prepended
// to the plaintext before encryption so it travels authenticated. Nonce is
// incremented after every Push.
type encryptor struct {
	gcm   cipher.AEAD
	nonce [nonceSize]byte
}

func (e *encryptor) Push(plain []byte, tag byte) ([]byte, error) {
	input := make([]byte, 1+len(plain))
	input[0] = tag
	copy(input[1:], plain)
	out := e.gcm.Seal(nil, e.nonce[:], input, nil)
	incNonce(&e.nonce)
	return out, nil
}

// decryptor opens each message with AES-256-GCM and extracts the tag byte.
type decryptor struct {
	gcm   cipher.AEAD
	nonce [nonceSize]byte
}

func (d *decryptor) Pull(ciphertext []byte) ([]byte, byte, error) {
	plain, err := d.gcm.Open(nil, d.nonce[:], ciphertext, nil)
	if err != nil {
		return nil, 0, err
	}
	if len(plain) < 1 {
		return nil, 0, fmt.Errorf("aesgcm: decrypted payload too short")
	}
	incNonce(&d.nonce)
	return plain[1:], plain[0], nil
}

func incNonce(nonce *[nonceSize]byte) {
	ctr := binary.LittleEndian.Uint32(nonce[:4])
	ctr++
	binary.LittleEndian.PutUint32(nonce[:4], ctr)
}
