#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "${ROOT_DIR}"
PYTHONPATH=week3/day3/labs/dockerhub-app \
  python3 -m unittest week3/day3/labs/dockerhub-app/test_app.py
