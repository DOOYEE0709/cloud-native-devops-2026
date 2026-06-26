#!/usr/bin/env bash
set -euo pipefail

echo "[ci] shell syntax"
bash -n week3/day3/labs/ci-gate-demo/app.sh
bash -n week3/day3/labs/ci-gate-demo/tests/smoke_test.sh

echo "[ci] smoke test"
bash week3/day3/labs/ci-gate-demo/tests/smoke_test.sh

echo "[ci] done"
