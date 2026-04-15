#!/usr/bin/env bash
set -euo pipefail

if [ -f /data/quickstart/ctrl.yaml ]; then
  echo "PKI and configs already exist, skipping quickstart"
  exit 0
fi

mkdir -p /data/quickstart

ziti edge quickstart \
  --home /data \
  --ctrl-address ziti-controller \
  --router-address ziti-router \
  --ctrl-port 1280 \
  --router-port 3022 \
  --configure-and-exit \
  -p admin123
