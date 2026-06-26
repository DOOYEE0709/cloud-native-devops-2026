#!/usr/bin/env bash
set -euo pipefail

output="$(APP_VERSION=0.1.0 APP_MESSAGE=ci-gate-ok bash week3/day3/labs/ci-gate-demo/app.sh)"

echo "${output}" | grep '"version":"0.1.0"' >/dev/null
echo "${output}" | grep '"message":"ci-gate-ok"' >/dev/null

echo "smoke-test-ok"
