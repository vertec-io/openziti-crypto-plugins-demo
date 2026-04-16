# OpenZiti Crypto Plugins Demo

An independent, reproducible demonstration of the cipher-negotiation extension
hooks proposed for [OpenZiti](https://github.com/openziti/ziti). This harness
builds controller, router, and SDK sample binaries from small, auditable forks,
runs a nine-cell interoperability matrix, and produces per-cell evidence files —
all from a single `docker compose` invocation.

This repository is a **standalone demonstration tool**. It is not part of the
OpenZiti project itself and carries no endorsement from the OpenZiti maintainers.

## Peer Variants

Every SDK (Go, C, JVM) is built in two configurations. Together with the
reference plugin, this gives three runtime variants:

| Variant    | Source                              | Cipher Behaviour                       |
|------------|-------------------------------------|----------------------------------------|
| **stock**    | Upstream `openziti/*` latest stable            | Default negotiation only               |
| **hook-off** | Hook-enabled fork, default config              | Hook extension compiled in but unused  |
| **hook-on**  | Hook-enabled fork + reference plugin           | Alternate cipher registered and offered |

*hook-off* proves the fork is a no-op when no plugin is loaded.
*hook-on* proves a plugin can register an alternate cipher and negotiate it.

## Interop Matrix

The matrix exercises nine cells across five groups. Each group isolates one
property of the hook architecture.

| Group             | Cell                   | Client        | Host          | Expected Outcome       |
|-------------------|------------------------|---------------|---------------|------------------------|
| **Baseline**      | `baseline-go`          | stock-go      | stock-go      | Default cipher         |
|                   | `baseline-c`           | stock-c       | stock-c       | Default cipher         |
|                   | `baseline-jvm`         | stock-jvm     | stock-jvm     | Default cipher         |
| **Hook neutrality** | `neutrality-go`      | hook-off-go   | hook-off-go   | Default cipher         |
|                   | `neutrality-c`         | hook-off-c    | hook-off-c    | Default cipher         |
|                   | `neutrality-jvm`       | hook-off-jvm  | hook-off-jvm  | Default cipher         |
| **Matched**       | `matched-go`           | hook-on-go    | hook-on-go    | Alternate cipher (AES-256-GCM) |
| **Mismatched**    | `mismatched-go`        | hook-on-go (id 2) | hook-on-go (id 99) | Both sides reject |
| **Fallback**      | `fallback-go`          | hook-on-go    | stock-go      | Graceful fallback to default |

**What each group proves:**

- **Baseline** — unmodified upstream binaries interoperate normally.
- **Hook neutrality** — the fork changes are invisible when no plugin is loaded;
  behaviour is identical to stock.
- **Matched** — when both peers offer the same alternate cipher, negotiation
  selects it and data flows end-to-end.
- **Mismatched** — when peers offer incompatible ciphers, both sides reject
  cleanly with no data corruption.
- **Fallback** — a hook-enabled peer degrades gracefully when its counterpart
  does not support negotiation.

## Reference Plugin

The `reference-plugin/go/` directory contains a minimal (~150 LOC) Go plugin
that registers AES-256-GCM via the hook API using only `crypto/aes` and
`crypto/cipher` from the Go standard library. It is **deliberately
non-production**: no policy enforcement, no approved-provider gating, no
hard-fail paths. On registration failure it logs to stderr and returns nil.

Prose porting notes for C and JVM are in
[reference-plugin/README.md](reference-plugin/README.md).

## Quick Start

```bash
git clone https://github.com/vertec-io/openziti-crypto-plugins-demo.git
cd openziti-crypto-plugins-demo
docker compose up --build -d
./scripts/wait-for-ready.sh
./runmatrix.sh --all
```

First run from a clean machine: 40-70 minutes (Docker builds five images from
source — ziti-controller, ziti-router, sample/go, sample/c, sample/jvm).
Subsequent matrix runs against the built images: under 5 minutes.

> A planned `prebuilt-images` branch will provide pre-built images for
> reviewers who prefer a ~10-minute pull over a from-source build.

Results are written to `evidence/` — one file per cell plus a
`matrix-summary.txt` with per-cell verdicts and wall-clock timing.

To tear down:

```bash
docker compose down -v
```

## Trace Contract

Every sample binary accepts a `--print-cipher` flag. On a successful
handshake it emits exactly one line to stdout:

```
NEGOTIATED-CIPHER:<id>
```

where `<id>` is a decimal integer identifying the negotiated cipher. The
harness scripts parse this line to determine the verdict for each cell:

- **PASS** — the observed cipher id matches the expected outcome.
- **REJECT-AS-EXPECTED** — both sides refused the handshake, which is the
  correct behaviour for the mismatched cell.
- **FAIL** — unexpected cipher id or missing trace line.

## What This Fork Changes

The hook-enabled forks add extension hooks to three areas of the OpenZiti
data path. Each change maps to a documented proposal PR:

**Controller + router (`vertec-io/ziti`, 4 commits, ~280 lines changed):**

- *PR 3* — Forward a cipher-preferences header through edge-router dial
  paths so that the hosting SDK can see what the client offered.
- *PR 7* — Add a controller startup lifecycle notifier so that plugins
  can register themselves before the first enrollment completes.
- *PR 2 consumer path* — Thread the cipher-provider interface through
  the router xgress setup so the negotiated provider is available at
  encryption time.
- *Build pin* — Lock `go.mod` dependencies to tagged fork versions of
  `secretstream` and `sdk-golang` so the build is reproducible without
  sibling checkouts.

**Go SDK (`vertec-io/sdk-golang`, 7 commits) and core library
(`vertec-io/secretstream`, 3 commits):**

- Introduce a `CryptoProvider` seam in `secretstream` for pluggable AEAD
  backends, with a default provider that preserves legacy behaviour.
- Surface cipher-negotiation failures as named errors.
- Emit the negotiated cipher id in structured logs.
- Add a `PreStartPolicy` gate so external code can intercept context
  construction.

**C SDK (`vertec-io/ziti-sdk-c`, 10 commits, ~900 lines changed):**

- Add a pluggable AEAD vtable and a CMake backend slot for alternate
  crypto implementations.
- Mirror the Go negotiation flow: send cipher preferences on dial,
  echo on reply, validate on both sides.
- Rename internal crypto-backend enum values to neutral identifiers.

All fork branches are named `feature/crypto-extensibility` and are pinned
to specific SHAs recorded in the harness Dockerfiles.

## Reproducibility

Every binary in this harness is built from a pinned commit SHA using
shallow clones with the `.git` directory stripped from the final image.
There are no floating tags, no `latest` references, and no host-local
dependencies beyond Docker and `git`.

To verify the fork delta yourself:

```bash
cd /tmp
git clone https://github.com/openziti/ziti.git && cd ziti
git remote add fork https://github.com/vertec-io/ziti.git
git fetch fork feature/crypto-extensibility
git diff main...fork/feature/crypto-extensibility --shortstat
```

## Project Structure

```
.
├── docker-compose.yml          # Controller, router, SDK builders
├── runmatrix.sh                # Run all 9 cells or a single group
├── runscenario.sh              # Run a single cell by id
├── cells/                      # Per-cell .params definitions
├── sample/
│   ├── go/                     # Go SDK stock + hook Dockerfile
│   ├── c/                      # C SDK stock + hook Dockerfile
│   └── jvm/                    # JVM SDK stock + hook Dockerfile
├── reference-plugin/
│   └── go/                     # Minimal AES-256-GCM reference plugin
├── scripts/
│   └── wait-for-ready.sh       # Poll controller health, 120s timeout
├── evidence/                   # Per-cell evidence files (gitignored)
├── examples/
│   └── sample-evidence/        # Known-good evidence from a reference run
├── CHANGELOG.md
├── CONTRIBUTING.md
└── LICENSE                     # Apache-2.0
```

## License

[Apache-2.0](LICENSE)
