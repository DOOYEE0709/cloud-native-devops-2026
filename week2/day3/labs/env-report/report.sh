#!/bin/sh
set -eu

echo "APP_ENV=${APP_ENV:-missing}"
echo "APP_PORT=${APP_PORT:-missing}"
echo "FEATURE_FLAG=${FEATURE_FLAG:-missing}"
echo "DB_HOST=${DB_HOST:-missing}"
echo "DB_PORT=${DB_PORT:-missing}"
