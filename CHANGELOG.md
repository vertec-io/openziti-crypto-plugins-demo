## v0.2.0 — 2026-04-16

Adds pre-built image distribution alongside the existing from-source path.
`main` continues to build all five images from source (40-70 minute cold
run); the new `prebuilt-images` branch pins published container images for
a sub-fifteen-minute fast-demo path. Both branches land identical nine-cell
matrix evidence.

Main SHA at release: `ee4498f3276364524d4fb6b48e23013cbf0b2765`
Prebuilt-images SHA at release: `e4789a26238b0105955297c21b2568add7659cbd`

### Added

- `.github/workflows/publish-images.yml` on `main` — every push builds,
  structurally scans for `.git` leakage, and publishes the five images to
  GitHub Container Registry under both `:latest` and `:sha-<short-sha>`
  tags.
- `prebuilt-images` branch — `docker-compose.yml` references the published
  images instead of building, and `image-manifest.txt` records the
  `sha256:...` digest of every pinned image.
- `.github/workflows/validate-prebuilt.yml` on `prebuilt-images` — on every
  push, PR, daily 06:00 UTC cron, and manual dispatch, pulls the five
  images, verifies each digest against `image-manifest.txt`, and runs the
  nine-cell matrix.
- `.github/workflows/sync-from-main.yml` on `main` — when `publish-images`
  completes on `main`, opens a PR against `prebuilt-images` updating
  compose tags and `image-manifest.txt` to the new `main` SHA.
- Branch protection on `prebuilt-images`: required PR review, required
  status check (`validate-prebuilt / pull-verify-matrix`), no direct push,
  no force-push, no branch deletion.

### Changed

- `README.md` on `main` gains a "Looking for a fast demo?" callout and a
  "Which branch should I use?" section linking to `prebuilt-images`.
- `README.md` on `prebuilt-images` rewritten to lead with the fast-path
  quick-start and the image-provenance verification recipe.

### Choose your path

- `main` — audit the full build chain from source (40-70 minutes first run).
- `prebuilt-images` — pull published images and run the matrix (under
  fifteen minutes first run), trusting the chain of custody recorded in
  `image-manifest.txt`.

Both paths land the same nine-cell evidence.

---

## v0.1.0 — 2026-04-16

First tagged release of the OpenZiti crypto plugins demo harness. Reproducibly
builds controller, router, and three SDK sample variants from pinned forks,
runs the nine-cell interop matrix, and writes per-cell evidence.

### What this harness proves

- Extension hooks in the controller, router, and all three SDKs can register
  an alternate cipher without touching upstream-stable wire behaviour.
- When no plugin is loaded, hook-enabled binaries behave identically to
  upstream (neutrality).
- When both peers load the same plugin, an alternate cipher is negotiated
  and data flows end-to-end (matched).
- When plugins differ, both peers reject cleanly without falling back to an
  insecure default (mismatched).
- When a hook-enabled peer meets an upstream peer, the default cipher is
  used and data flows (fallback).

Nine interop cells across Go, C, and JVM prove the four properties above.

### Quick start

```
docker compose --profile build-only build
docker compose up --build -d
./scripts/wait-for-ready.sh
./runmatrix.sh --all
```

First cold build takes 40-70 minutes (from-source fork builds and vcpkg
dependency compilation). Subsequent rebuilds with the BuildKit layer cache
complete in under 5 minutes.

### Pinned upstream SHAs

| Component      | Repo                        | SHA       |
|----------------|-----------------------------|-----------|
| ziti           | vertec-io/ziti              | d9a20d9   |
| ziti-sdk-c     | vertec-io/ziti-sdk-c        | 53f2c67   |
| secretstream   | vertec-io/secretstream      | ad2b8b6   |
| sdk-golang     | vertec-io/sdk-golang        | 6c0300d   |
| ziti-sdk-jvm   | vertec-io/ziti-sdk-jvm      | 67e9185   |

Full 40-char SHAs are tracked in `pinned-shas.txt` and enforced by the
build from `docker-compose.yml` x-sha anchors.

### Components

- JVM SDK sample JARs: stock + hook-enabled client/host with `--print-cipher` trace
  (stock: org.openziti:ziti:0.33.0; hook: vertec-io/ziti-sdk-jvm at 67e9185,
  branch feature/crypto-extensibility, JDK-default JCE providers only)
- C SDK sample binaries: stock + hook-enabled client/host with `--print-cipher` trace
  (stock: openziti/ziti-sdk-c 1.14.3; hook: vertec-io/ziti-sdk-c at 53f2c67,
  branch feature/crypto-extensibility, `-DZITI_CRYPTO_BACKEND=openssl`)
- Go SDK sample binaries: stock + hook-enabled client/host with `--print-cipher` trace
  (stock: openziti/sdk-golang v1.6.0; hook: vertec-io/sdk-golang at 6c0300d, tag v1.6.1-ext.0)
- Docker Compose build for ziti-controller and ziti-router from hook-enabled fork
  (pinned SHA: d9a20d9dad8c58f098f989eb1668ed657c0500c5)
- Go reference plugin (`reference-plugin/go`) registering AES-256-GCM as an
  alternate cipher; stdlib-only, 109 lines of code
- GitHub Actions matrix workflow building all five images and running the
  nine-cell interop matrix on every push
- Per-cell evidence artifacts (`stdout.log`, `cipher-trace.log`,
  `RESULT.txt`) suitable for third-party audit
