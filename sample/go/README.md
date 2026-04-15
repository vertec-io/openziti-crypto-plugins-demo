# Go SDK Sample Binaries

Four binaries demonstrating cipher negotiation with the OpenZiti Go SDK.

## Variants

| Binary | SDK Source | Description |
|--------|-----------|-------------|
| `stock-client` | upstream `openziti/sdk-golang` v1.6.0 | Client using unmodified SDK |
| `stock-host` | upstream `openziti/sdk-golang` v1.6.0 | Host using unmodified SDK |
| `hook-client` | `vertec-io/sdk-golang` at pinned SHA | Client using hook-enabled SDK fork |
| `hook-host` | `vertec-io/sdk-golang` at pinned SHA | Host using hook-enabled SDK fork |

## Pinned SHAs

- `sdk-golang`: `6c0300dc1b3b739088f13d71a841ad6914af817b` (tag `v1.6.1-ext.0`)
- `secretstream`: `ad2b8b621d6820468b6c82b35d06b3dd6bc781a1` (tag `v0.1.50-ext.0`)

Source of truth: `pinned-shas.txt` in the orchestration repo.

## Build

```bash
docker compose build go-sdk
```

The Dockerfile uses multi-stage builds:
- **stock-builder**: fetches upstream `openziti/sdk-golang@v1.6.0`
- **hook-builder**: shallow-clones `vertec-io/sdk-golang` at the pinned SHA with `.git` stripped

Both use `-trimpath -ldflags='-s -w -buildid='` for reproducible builds.

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
