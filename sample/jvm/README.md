# JVM SDK Cipher Interop Samples

Builds four fat JARs for the cipher-negotiation interop matrix:

| Binary | SDK Source | Cipher |
|--------|-----------|--------|
| `stock-client.jar` | upstream `org.openziti:ziti:0.33.0` | Default (ChaCha20-Poly1305) |
| `stock-host.jar` | upstream `org.openziti:ziti:0.33.0` | Default (ChaCha20-Poly1305) |
| `hook-client.jar` | `vertec-io/ziti-sdk-jvm` @ `67e9185` | Hook-enabled, default cipher |
| `hook-host.jar` | `vertec-io/ziti-sdk-jvm` @ `67e9185` | Hook-enabled, default cipher |

## Pinned SHAs

- **Hook SDK:** `ziti-sdk-jvm=67e91851c81ba6b82db1d768bf6673e187cc036a` (branch `feature/crypto-extensibility`)
- **Stock SDK:** `org.openziti:ziti:0.33.0` from Maven Central

## Build

```bash
docker compose build jvm-sdk
```

## Usage

Each JAR accepts:

```
java -jar <jar> --identity /path/to/identity.json [--service cipher-interop-svc] [--print-cipher]
```

- `--identity` (required): path to enrolled Ziti identity JSON
- `--service`: service name (default: `cipher-interop-svc`)
- `--print-cipher`: emit `NEGOTIATED-CIPHER:<id>` to stdout on successful handshake

## JCE Providers

All JARs run with JDK-default JCE providers only. No JSSE overrides, no custom security
providers at launch. The upstream `org.bouncycastle:bcpkix-jdk18on` transitive dependency is
the vanilla (non-validated) BouncyCastle distribution.
