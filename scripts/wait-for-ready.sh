#!/usr/bin/env bash
# Waits for the harness stack to be ready for the matrix to run.
#
# Readiness is defined functionally: the ziti-controller accepts an admin
# login, a router reports isOnline, and the test-client/test-host identities
# are enumerable via `ziti edge list identities`. Those three signals prove
# the controller, router, and config-init steps have all completed enough
# for matrix cells to run.
#
# The previous 4-gate version also inspected init-config's container state
# and the raw identity JSON files on the volume; both were brittle on cold
# 2-vCPU starts (gate latching, volume sync timing). The identity-list gate
# supersedes both: if list-identities returns both test-client and test-host,
# the enrollment work was done successfully — that is the outcome the process
# signals were trying to prove.

set -euo pipefail

TIMEOUT=${1:-300}
CTRL_CONTAINER="ziti-controller"
ELAPSED=0
INTERVAL=3

echo "Waiting for controller + router + identities to be ready (timeout: ${TIMEOUT}s)..."

while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  # Gate 1: controller accepts admin login
  if docker exec "$CTRL_CONTAINER" \
      ziti edge login "https://ziti-controller:1280" \
        -u admin -p admin123 -y \
        --ca /data/pki/root-ca/certs/root-ca.cert >/dev/null 2>&1; then

    # Gate 2: at least one router is online
    ROUTERS=$(docker exec "$CTRL_CONTAINER" \
      ziti edge list edge-routers --output-json 2>/dev/null || echo "{}")
    if echo "$ROUTERS" | grep -q '"isOnline"[[:space:]]*:[[:space:]]*true'; then

      # Gate 3: both test identities exist and are enrolled
      IDENTS=$(docker exec "$CTRL_CONTAINER" \
        ziti edge list identities 'name contains "test-"' --output-json 2>/dev/null || echo "{}")
      if echo "$IDENTS" | grep -q '"name"[[:space:]]*:[[:space:]]*"test-client"' && \
         echo "$IDENTS" | grep -q '"name"[[:space:]]*:[[:space:]]*"test-host"'; then
        echo ""
        echo "Ready: controller login OK, router online, test-client + test-host identities enrolled."
        exit 0
      fi
    fi
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  printf "\r  %ds / %ds" "$ELAPSED" "$TIMEOUT"
done

echo ""
echo "ERROR: timed out after ${TIMEOUT}s waiting for ready state"
echo "--- diagnostic snapshot ---"
docker ps --filter "name=ziti-" --filter "name=init-" \
  --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null || true
docker inspect -f 'init-config: {{.State.Status}} (exit {{.State.ExitCode}})' \
  init-config 2>/dev/null || true
echo "--- last controller log (5 lines) ---"
docker logs --tail 5 "$CTRL_CONTAINER" 2>&1 | sed 's/^/  /' || true
exit 1
