#!/usr/bin/env bash
set -euo pipefail

output="$(APP_VERSION=0.1.0 APP_MESSAGE=ci-gate-ok bash week3/day3/labs/ci-gate-demo/app.sh)"

echo "${output}" | grep '"message":"expected-different-message"' >/dev/null

echo "this line should not run"
