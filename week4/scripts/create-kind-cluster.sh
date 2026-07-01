#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${1:-paperclip-w4}"
EXPECTED_CONTEXT="kind-${CLUSTER_NAME}"

echo "[cluster] target kind cluster: ${CLUSTER_NAME}"

if kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  echo "[cluster] already exists: ${CLUSTER_NAME}"
else
  echo "[cluster] creating: ${CLUSTER_NAME}"
  kind create cluster --name "${CLUSTER_NAME}"
fi

kubectl config use-context "${EXPECTED_CONTEXT}"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "[cluster] ERROR: current context is ${CURRENT_CONTEXT}, expected ${EXPECTED_CONTEXT}" >&2
  exit 1
fi

echo "[cluster] current context: ${CURRENT_CONTEXT}"
kubectl get nodes -o wide

