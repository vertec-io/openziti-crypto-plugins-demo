# C SDK Sample Binaries

Four binaries demonstrating cipher negotiation with the OpenZiti C SDK.

## Variants

| Binary | SDK Source | Description |
|--------|-----------|-------------|
| `stock-client` | upstream `openziti/ziti-sdk-c` 1.14.3 | Client using unmodified SDK |
| `stock-host` | upstream `openziti/ziti-sdk-c` 1.14.3 | Host using unmodified SDK |
| `hook-client` | `vertec-io/ziti-sdk-c` at pinned SHA | Client using hook-enabled SDK fork |
| `hook-host` | `vertec-io/ziti-sdk-c` at pinned SHA | Host using hook-enabled SDK fork |

## Pinned SHAs

- `ziti-sdk-c`: `53f2c67763797d53466ab5f786660fa26fce4939` (branch `feature/crypto-extensibility`)

Source of truth: `pinned-shas.txt` in the orchestration repo.

## Build

```bash
docker compose build c-sdk
```

The Dockerfile uses multi-stage builds:
- **stock-builder**: clones upstream `openziti/ziti-sdk-c` at tag `1.14.3`
- **hook-builder**: shallow-clones `vertec-io/ziti-sdk-c` at the pinned SHA with `.git` stripped; builds with `-DZITI_CRYPTO_BACKEND=openssl` using system OpenSSL

Both use vcpkg for dependencies (libsodium, libuv, openssl, zlib, etc.) with static linking.

## Usage

All binaries accept the same flags:

```
--identity <path>   Path to OpenZiti identity JSON file (required)
--service <name>    Service name (default: cipher-interop-svc)
--print-cipher      Print NEGOTIATED-CIPHER:<id> after handshake and exit
```

### Trace contract

On successful handshake with `--print-cipher`, each binary emits exactly one line:

```
NEGOTIATED-CIPHER:<id>
```

where `<id>` is the decimal cipher ID (e.g., `1` for ChaCha20-Poly1305).
