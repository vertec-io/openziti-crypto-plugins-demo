## Unreleased

- C SDK sample binaries: stock + hook-enabled client/host with `--print-cipher` trace
  (stock: openziti/ziti-sdk-c 1.14.3; hook: vertec-io/ziti-sdk-c at 53f2c67,
  branch feature/crypto-extensibility, `-DZITI_CRYPTO_BACKEND=openssl`)
- Go SDK sample binaries: stock + hook-enabled client/host with `--print-cipher` trace
  (stock: openziti/sdk-golang v1.6.0; hook: vertec-io/sdk-golang at 6c0300d, tag v1.6.1-ext.0)
- Docker Compose build for ziti-controller and ziti-router from hook-enabled fork
  (pinned SHA: d9a20d9dad8c58f098f989eb1668ed657c0500c5)
