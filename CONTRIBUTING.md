# Contributing

## Development setup

1. Clone the repo and its dependencies:
   ```bash
   git clone https://github.com/vertec-io/openziti-crypto-plugins-demo.git
   cd openziti-crypto-plugins-demo
   ```
2. Install Docker and Docker Compose.
3. Build and bring up the environment:
   ```bash
   docker compose up --build -d
   ./scripts/wait-for-ready.sh
   ```

## How to add a cell

Each cell in the interop matrix is defined by a `.params` file in `cells/`.
The format is shell-eval-safe `key=value` pairs (sourced by `runscenario.sh`):

```bash
# cells/my-new-cell.params
CLIENT_VARIANT=hook-go
HOST_VARIANT=hook-go
CLIENT_PREFS=2
HOST_PREFS=2
EXPECTED_OUTCOME=PASS
```

### Required keys

| Key | Description | Values |
|-----|-------------|--------|
| `CLIENT_VARIANT` | SDK variant for the client binary | `stock-go`, `hook-go`, `stock-c`, `hook-c`, `stock-jvm`, `hook-jvm` |
| `HOST_VARIANT` | SDK variant for the host binary | same as above |
| `CLIENT_PREFS` | Cipher preference hint (informational) | cipher ID or empty |
| `HOST_PREFS` | Cipher preference hint (informational) | cipher ID or empty |
| `EXPECTED_OUTCOME` | Expected result | `PASS` (matching ciphers) or `REJECT` (negotiation failure) |

### Running a single cell

```bash
./runscenario.sh my-new-cell
```

This produces `evidence/my-new-cell.txt` with the test results. Exit code 0
means the cell matched expectations (PASS or REJECT-AS-EXPECTED).
