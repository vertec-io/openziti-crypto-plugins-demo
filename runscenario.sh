#!/usr/bin/env bash
set -euo pipefail

# runscenario.sh — run a single interop matrix cell and produce evidence.
#
# Usage: ./runscenario.sh <cell-id>
#
# Reads cells/<cell-id>.params and launches the specified client+host
# binary pair. Parses NEGOTIATED-CIPHER:<id> from stdout, compares
# against EXPECTED_OUTCOME, writes evidence/<cell-id>.txt.

CELL_ID="${1:?Usage: runscenario.sh <cell-id>}"
PARAMS_FILE="cells/${CELL_ID}.params"

if [[ ! -f "$PARAMS_FILE" ]]; then
  echo "ERROR: $PARAMS_FILE not found" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$PARAMS_FILE"

# Validate required keys
for key in CLIENT_VARIANT HOST_VARIANT EXPECTED_OUTCOME; do
  if [[ -z "${!key:-}" ]]; then
    echo "ERROR: $key not set in $PARAMS_FILE" >&2
    exit 1
  fi
done

# Map variant to image + binary path
resolve_variant() {
  local variant="$1" role="$2"  # role: client or host
  local image binary

  case "$variant" in
    stock-go)  image="openziti-go-sdk-samples:local";  binary="/usr/local/bin/stock-${role}" ;;
    hook-go)   image="openziti-go-sdk-samples:local";  binary="/usr/local/bin/hook-${role}" ;;
    stock-c)   image="openziti-c-sdk-samples:local";   binary="/usr/local/bin/stock-${role}" ;;
    hook-c)    image="openziti-c-sdk-samples:local";   binary="/usr/local/bin/hook-${role}" ;;
    stock-jvm) image="openziti-jvm-sdk-samples:local"; binary="java -jar /app/stock-${role}.jar" ;;
    hook-jvm)  image="openziti-jvm-sdk-samples:local"; binary="java -jar /app/hook-${role}.jar" ;;
    *) echo "ERROR: unknown variant: $variant" >&2; exit 1 ;;
  esac

  echo "$image|$binary"
}

NETWORK="openziti-crypto-plugins-demo_ziti-net"
VOLUME="openziti-crypto-plugins-demo_ziti-data"
HOST_IDENTITY="/data/identities/test-host.json"
CLIENT_IDENTITY="/data/identities/test-client.json"
TIMEOUT_SECS=60

HOST_RESOLVED=$(resolve_variant "$HOST_VARIANT" "host")
HOST_IMAGE="${HOST_RESOLVED%%|*}"
HOST_BINARY="${HOST_RESOLVED#*|}"

CLIENT_RESOLVED=$(resolve_variant "$CLIENT_VARIANT" "client")
CLIENT_IMAGE="${CLIENT_RESOLVED%%|*}"
CLIENT_BINARY="${CLIENT_RESOLVED#*|}"

HOST_CONTAINER="scenario-host-${CELL_ID}-$$"
CLIENT_CONTAINER="scenario-client-${CELL_ID}-$$"

cleanup() {
  docker rm -f "$HOST_CONTAINER" >/dev/null 2>&1 || true
  docker rm -f "$CLIENT_CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "=== Cell: $CELL_ID ==="
echo "  Host:   $HOST_VARIANT ($HOST_IMAGE)"
echo "  Client: $CLIENT_VARIANT ($CLIENT_IMAGE)"
echo "  Expected: $EXPECTED_OUTCOME"

# Launch host (no --rm so we can capture logs after exit)
docker run -d \
  --name "$HOST_CONTAINER" \
  --network "$NETWORK" \
  -v "${VOLUME}:/data" \
  "$HOST_IMAGE" \
  $HOST_BINARY --identity "$HOST_IDENTITY" --print-cipher \
  >/dev/null 2>&1

# Wait for host to be listening, then launch client
sleep 5

CLIENT_OUTPUT=$(timeout "$TIMEOUT_SECS" docker run \
  --name "$CLIENT_CONTAINER" \
  --network "$NETWORK" \
  -v "${VOLUME}:/data" \
  "$CLIENT_IMAGE" \
  $CLIENT_BINARY --identity "$CLIENT_IDENTITY" --print-cipher \
  2>&1) || true

# Wait for host to finish and capture its output
sleep 3
HOST_OUTPUT=$(docker logs "$HOST_CONTAINER" 2>&1) || HOST_OUTPUT="(host exited before log capture)"

# Parse cipher IDs
CLIENT_CIPHER=$(echo "$CLIENT_OUTPUT" | grep -oP 'NEGOTIATED-CIPHER:\K\d+' || echo "NONE")
HOST_CIPHER=$(echo "$HOST_OUTPUT" | grep -oP 'NEGOTIATED-CIPHER:\K\d+' || echo "NONE")

# Determine verdict
VERDICT="FAIL"
case "$EXPECTED_OUTCOME" in
  PASS)
    if [[ "$CLIENT_CIPHER" != "NONE" && "$HOST_CIPHER" != "NONE" && "$CLIENT_CIPHER" == "$HOST_CIPHER" ]]; then
      VERDICT="PASS"
    fi
    ;;
  REJECT)
    if [[ "$CLIENT_CIPHER" == "NONE" || "$HOST_CIPHER" == "NONE" ]]; then
      VERDICT="REJECT-AS-EXPECTED"
    fi
    ;;
  *)
    echo "ERROR: unknown EXPECTED_OUTCOME: $EXPECTED_OUTCOME" >&2
    exit 1
    ;;
esac

# Write evidence file
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EVIDENCE_FILE="evidence/${CELL_ID}.txt"
mkdir -p evidence

cat > "$EVIDENCE_FILE" <<EVIDENCE
Cell: $CELL_ID
Timestamp: $TIMESTAMP
Client variant: $CLIENT_VARIANT
Host variant: $HOST_VARIANT
Expected outcome: $EXPECTED_OUTCOME

--- Client stdout ---
$CLIENT_OUTPUT

--- Host stdout ---
$HOST_OUTPUT

--- Parsed cipher IDs ---
Client: $CLIENT_CIPHER
Host: $HOST_CIPHER

--- Verdict ---
$VERDICT
EVIDENCE

echo "  Client cipher: $CLIENT_CIPHER"
echo "  Host cipher:   $HOST_CIPHER"
echo "  Verdict:       $VERDICT"
echo "  Evidence:      $EVIDENCE_FILE"

if [[ "$VERDICT" == "PASS" || "$VERDICT" == "REJECT-AS-EXPECTED" ]]; then
  exit 0
else
  exit 1
fi
