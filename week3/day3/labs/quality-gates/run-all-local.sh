#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "${ROOT_DIR}"

echo "[gate] unit test"
bash week3/day3/labs/quality-gates/unit-test.sh

echo "[gate] sast scan"
bash week3/day3/labs/quality-gates/sast-scan.sh

echo "[gate] docker build"
docker build \
  --build-arg APP_VERSION=0.1.0 \
  -t w3d3-dockerhub-app:0.1.0 \
  week3/day3/labs/dockerhub-app

echo "[gate] dast health check"
bash week3/day3/labs/quality-gates/dast-health-check.sh

echo "quality-gates-ok"
