#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

measure() {
  local target="$1"
  local dockerfile="$2"
  local context="$3"
  local base="$4"
  local tag="paperclip-weekend-${target}:${base//[:\/]/-}"
  local start end seconds size_bytes size_human

  start="$(date +%s)"
  docker build --no-cache -f "$dockerfile" --build-arg BASE_IMAGE="$base" -t "$tag" "$context" >/tmp/paperclip-${target}-${base//[:\/]/-}.build.log
  end="$(date +%s)"
  seconds="$((end - start))"
  size_bytes="$(docker image inspect "$tag" --format '{{.Size}}')"
  size_human="$(docker images "$tag" --format '{{.Size}}')"
  printf '%s,%s,%s,%s,%s\n' "$target" "$base" "$seconds" "$size_bytes" "$size_human"
}

echo "target,base,seconds,size_bytes,size_human"
measure "frontend" "frontend/Dockerfile.size-compare" "frontend" "nginx:stable"
measure "frontend" "frontend/Dockerfile.size-compare" "frontend" "nginx:stable-alpine"
measure "frontend" "frontend/Dockerfile.size-compare" "frontend" "nginx:stable-trixie"
measure "backend" "backend/Dockerfile.size-compare" "backend" "node:22"
measure "backend" "backend/Dockerfile.size-compare" "backend" "node:22-slim"
measure "backend" "backend/Dockerfile.size-compare" "backend" "node:22-alpine"
