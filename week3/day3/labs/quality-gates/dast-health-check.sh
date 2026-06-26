#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "${ROOT_DIR}"

IMAGE="${IMAGE:-w3d3-dockerhub-app:0.1.0}"
CONTAINER="${CONTAINER:-w3d3-dast-check}"
PORT="${PORT:-18089}"

docker rm -f "${CONTAINER}" 2>/dev/null || true
docker run -d --name "${CONTAINER}" -p "${PORT}:8080" "${IMAGE}" >/dev/null

cleanup() {
  docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for _ in 1 2 3 4 5; do
  if curl -fsS "http://localhost:${PORT}/health" 2>/dev/null | grep '"status": "ok"' >/dev/null; then
    echo "dast-health-check-ok"
    exit 0
  fi
  sleep 1
done

echo "dast-health-check-failed"
docker logs --tail=50 "${CONTAINER}" || true
exit 1
