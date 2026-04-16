#!/usr/bin/env bash
set -euo pipefail

TIMEOUT=${1:-180}
CTRL_CONTAINER="ziti-controller"
INIT_CONFIG_CONTAINER="init-config"
ELAPSED=0

echo "Waiting for controller and router to be ready (timeout: ${TIMEOUT}s)..."

while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  # Controller reachable + admin login works
  if docker exec "$CTRL_CONTAINER" \
    ziti edge login "https://ziti-controller:1280" \
      -u admin -p admin123 -y \
      --ca /data/pki/root-ca/certs/root-ca.cert >/dev/null 2>&1; then

    # Router online
    ROUTER_CHECK=$(docker exec "$CTRL_CONTAINER" \
      ziti edge list edge-routers --output-json 2>/dev/null || echo "{}")

    if echo "$ROUTER_CHECK" | grep -q '"isOnline".*true'; then
      # init-config container has exited cleanly (0) — this is the
      # authoritative signal that enrollments + service + policies
      # are complete and identity files are on the volume.
      IC_STATE=$(docker inspect -f '{{.State.Status}}:{{.State.ExitCode}}' \
        "$INIT_CONFIG_CONTAINER" 2>/dev/null || echo "missing:-1")

      if [ "$IC_STATE" = "exited:0" ]; then
        # Defense-in-depth: also verify both identity JSONs exist.
        IDENTITY_FILES_OK=$(docker exec "$CTRL_CONTAINER" \
          sh -c 'test -s /data/identities/test-client.json && test -s /data/identities/test-host.json && echo OK || echo NO' 2>/dev/null || echo "NO")

        if [ "$IDENTITY_FILES_OK" = "OK" ]; then
          echo ""
          echo "Controller healthy, router online, init-config exited(0), identity files present."
          exit 0
        fi
      fi
    fi
  fi

  sleep 3
  ELAPSED=$((ELAPSED + 3))
  printf "\r  %ds / %ds" "$ELAPSED" "$TIMEOUT"
done

echo ""
echo "ERROR: timed out after ${TIMEOUT}s waiting for ready state"
docker inspect -f 'init-config: {{.State.Status}} (exit {{.State.ExitCode}})' \
  "$INIT_CONFIG_CONTAINER" 2>/dev/null || true
exit 1
