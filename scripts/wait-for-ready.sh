#!/usr/bin/env bash
set -euo pipefail

TIMEOUT=${1:-120}
CTRL_CONTAINER="ziti-controller"
ELAPSED=0

echo "Waiting for controller and router to be ready (timeout: ${TIMEOUT}s)..."

while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  if docker exec "$CTRL_CONTAINER" \
    ziti edge login "https://ziti-controller:1280" \
      -u admin -p admin123 -y \
      --ca /data/pki/root-ca/certs/root-ca.cert >/dev/null 2>&1; then

    ROUTER_CHECK=$(docker exec "$CTRL_CONTAINER" \
      ziti edge list edge-routers --output-json 2>/dev/null || echo "{}")

    if echo "$ROUTER_CHECK" | grep -q '"isOnline".*true'; then
      IDENTITY_CHECK=$(docker exec "$CTRL_CONTAINER" \
        ziti edge list identities 'name="test-client"' --output-json 2>/dev/null || echo "{}")

      if echo "$IDENTITY_CHECK" | grep -q '"name".*"test-client"'; then
        echo ""
        echo "Controller is healthy, router is online, identities provisioned."
        exit 0
      fi
    fi
  fi

  sleep 3
  ELAPSED=$((ELAPSED + 3))
  printf "\r  %ds / %ds" "$ELAPSED" "$TIMEOUT"
done

echo ""
echo "ERROR: timed out after ${TIMEOUT}s waiting for ready state"
exit 1
