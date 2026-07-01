#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${1:-paperclip-w4}"

echo "[cluster] deleting kind cluster: ${CLUSTER_NAME}"
kind delete cluster --name "${CLUSTER_NAME}"

echo "[cluster] remaining kind clusters:"
kind get clusters || true

