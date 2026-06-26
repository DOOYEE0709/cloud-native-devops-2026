#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "${ROOT_DIR}"

echo "[sast] suspicious Python patterns"
if grep -RInE "eval\\(|exec\\(|subprocess\\.(Popen|call|run).*shell=True|pickle\\.loads" \
  week3/day3/labs/dockerhub-app; then
  echo "[sast] failed: suspicious pattern found"
  exit 1
fi

echo "[sast] secret-like patterns"
if grep -RInE "(password|token|secret|access_key).*=.+['\\\"][^'\\\"]{8,}" \
  week3/day3/labs/dockerhub-app week3/day3/labs/github-actions; then
  echo "[sast] failed: possible hardcoded secret"
  exit 1
fi

echo "sast-scan-ok"
