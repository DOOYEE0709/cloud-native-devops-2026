#!/usr/bin/env sh
set -eu

echo "APP_ENV=${APP_ENV:-missing}"
echo "FEATURE_FLAG=${FEATURE_FLAG:-missing}"
if [ -n "${DB_PASSWORD:-}" ]; then
  echo "DB_PASSWORD=***masked***"
else
  echo "DB_PASSWORD=missing"
fi
