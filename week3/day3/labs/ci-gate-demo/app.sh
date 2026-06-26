#!/usr/bin/env bash
set -euo pipefail

VERSION="${APP_VERSION:-0.1.0}"
MESSAGE="${APP_MESSAGE:-ci-gate-ok}"

printf '{"version":"%s","message":"%s"}\n' "${VERSION}" "${MESSAGE}"
