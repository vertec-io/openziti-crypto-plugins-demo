# Go Reference Plugin: AES-256-GCM

> **NOT FOR PRODUCTION USE.** This is an educational reference demonstrating
> how to register an alternate cipher via the OpenZiti secretstream hook API.
> It uses Go standard-library `crypto/aes` + `crypto/cipher`, which are **not**
> backed by any validated cryptographic module.

## How it works

The plugin implements `secretstream.CryptoProvider` and calls
`secretstream.RegisterDefault()` in its `init()` function. Any Go binary that
blank-imports this package will negotiate AES-256-GCM (cipher ID 2) instead
of the built-in ChaCha20-Poly1305 (cipher ID 1).

## Build

The plugin is compiled as part of the hook-enabled Go sample binaries.
The `sample/go/Dockerfile` copies this directory into the Docker build context
and enables it via the `hook` build tag:

```bash
# Build hook-enabled Go samples (includes plugin)
docker compose build go-sdk
```

To use the plugin in your own Go binary:

```go
import _ "path/to/reference-plugin/go"  // blank import in main package
```

The `init()` call runs before `main()`, so the provider is registered before
any secretstream operation.

## Verification

After building, run a hook-client against a hook-host. Both should report
cipher ID 2:

```
NEGOTIATED-CIPHER:2
```

## Design constraints

- Single file, <=150 LOC (non-blank, non-comment)
- Only `crypto/aes` + `crypto/cipher` from Go standard library
- Silent fallback on registration failure (log to stderr, no panic)
- No policy provider, no approved-only mode, no module enforcement
