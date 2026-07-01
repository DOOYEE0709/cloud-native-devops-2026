#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${1:-paperclip-w4}"
EXPECTED_CONTEXT="kind-${CLUSTER_NAME}"
CURRENT_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"

if [[ "${CURRENT_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "[context] ERROR: current context is '${CURRENT_CONTEXT:-none}'." >&2
  echo "[context] Expected '${EXPECTED_CONTEXT}'." >&2
  echo "[context] Run: bash week4/scripts/create-kind-cluster.sh ${CLUSTER_NAME}" >&2
  exit 1
fi

echo "[context] OK: ${CURRENT_CONTEXT}"

