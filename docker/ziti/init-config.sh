#!/usr/bin/env bash
set -euo pipefail

CTRL_URL="https://ziti-controller:1280"
CA_CERT="/data/pki/root-ca/certs/root-ca.cert"

echo "Waiting for controller edge API..."
for i in $(seq 1 60); do
  if ziti edge login "$CTRL_URL" -u admin -p admin123 -y --ca "$CA_CERT" 2>/dev/null; then
    echo "Logged in to controller"
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "ERROR: controller not ready after 60 attempts"
    exit 1
  fi
  sleep 2
done

echo "Waiting for router to come online..."
for i in $(seq 1 60); do
  ROUTER_JSON=$(ziti edge list edge-routers --output-json 2>/dev/null || echo "")
  if echo "$ROUTER_JSON" | grep -q '"isOnline".*true'; then
    echo "Router is online"
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "ERROR: router not online after 60 attempts"
    exit 1
  fi
  sleep 2
done

echo "Creating test identities..."
mkdir -p /data/identities

ziti edge create identity test-client \
  -a test-clients \
  -o /data/identities/test-client.jwt

ziti edge create identity test-host \
  -a test-hosts \
  -o /data/identities/test-host.jwt

echo "Enrolling test identities..."
ziti edge enroll \
  --jwt /data/identities/test-client.jwt \
  --out /data/identities/test-client.json \
  --ca "$CA_CERT"

ziti edge enroll \
  --jwt /data/identities/test-host.jwt \
  --out /data/identities/test-host.json \
  --ca "$CA_CERT"

echo "Creating cipher-interop-svc service..."
ziti edge create service cipher-interop-svc \
  -a cipher-interop-services \
  --encryption ON

echo "Creating service policies..."
ziti edge create service-policy cipher-interop-bind Bind \
  --service-roles '#cipher-interop-services' \
  --identity-roles '#test-hosts'

ziti edge create service-policy cipher-interop-dial Dial \
  --service-roles '#cipher-interop-services' \
  --identity-roles '#test-clients'

echo "Creating edge-router policy..."
ziti edge create edge-router-policy cipher-interop-erp \
  --edge-router-roles '#all' \
  --identity-roles '#all'

echo "Creating service-edge-router policy..."
ziti edge create service-edge-router-policy cipher-interop-serp \
  --service-roles '#all' \
  --edge-router-roles '#all'

echo "Bootstrap complete. Identities written to /data/identities/"
echo "  test-client.json"
echo "  test-host.json"
