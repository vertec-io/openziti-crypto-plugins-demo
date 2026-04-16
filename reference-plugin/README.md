# Reference Plugin

> **NOT FOR PRODUCTION USE.** These materials are educational references
> demonstrating how to register an alternate cipher via the OpenZiti
> secretstream hook architecture. A production plugin would replace the
> standard-library crypto calls with operations inside a validated
> cryptographic module.

## Go plugin

A working Go reference plugin is in [`go/`](go/). It registers AES-256-GCM
(cipher ID 2) as the default `secretstream.CryptoProvider` using only Go
standard-library `crypto/aes` + `crypto/cipher`. See [`go/README.md`](go/README.md)
for build and usage instructions.

**LOC count (non-blank, non-comment Go):** 109 (`cloc reference-plugin/go/aesgcm.go`)

## Porting notes: C SDK

The C SDK (`ziti-sdk-c`) exposes the cipher-extensibility hook through the
`ZITI_CRYPTO_BACKEND` CMake option and the `ziti_crypto_provider` struct.

To implement an alternate cipher in C:

1. **Define a provider struct** implementing the function pointers in
   `ziti_crypto_provider`: `name`, `ciphers`, `negotiate_as_server`,
   `negotiate_as_client`, `new_encryptor`, `new_decryptor_from_header`,
   `preferences_bytes`, and `wire_version`.

2. **Register the provider** by calling `ziti_set_crypto_provider()` before
   any SDK connection is established. Typically this is done in `main()`
   before `ziti_context_init()`.

3. **Link against your AEAD library.** The C SDK builds with
   `-DZITI_CRYPTO_BACKEND=openssl` by default; a custom backend would supply
   its own AES-GCM (or other AEAD) implementation via the provider struct.

4. **Advertise cipher preferences** via the `preferences_bytes` callback,
   returning a byte array of supported `cipher_id` values in priority order.

The negotiation protocol is symmetric with the Go API: server and client each
advertise their preference lists, and the first mutually-supported cipher wins.

## Porting notes: JVM SDK

The JVM SDK (`ziti-sdk-jvm`) exposes the hook through `CryptoProvider` (Kotlin
interface in the `org.openziti.crypto` package) and `DefaultCryptoProvider`.

To implement an alternate cipher in JVM:

1. **Implement `CryptoProvider`** with methods matching the Go interface:
   `name()`, `ciphers()`, `negotiateCipherAsServer()`,
   `negotiateCipherAsClient()`, `newEncryptor()`, `newDecryptorFromHeader()`,
   `preferencesBytes()`, and `wireVersion()`.

2. **Register via `DefaultCryptoProvider.register()`** before any Ziti context
   is created. A Kotlin `object` with an `init` block, loaded via
   `Class.forName()` or a blank reference in `main()`, mirrors the Go
   blank-import pattern.

3. **Use JCA for AEAD.** `javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")`
   with the JDK-default provider supplies AES-256-GCM. A production plugin
   would configure a specific JCA provider (e.g., a validated PKCS#11 bridge).

4. **Advertise cipher preferences** via `preferencesBytes()`, returning a
   `ByteArray` of supported cipher IDs.

The negotiation semantics, wire framing, and cipher ID space are identical
across all three SDKs.
