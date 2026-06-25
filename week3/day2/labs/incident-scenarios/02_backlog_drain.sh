#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../../../day1/labs/msa-demo"

PREFIX="${PREFIX:-day2-backlog-$(date +%s)}"
COUNT="${COUNT:-5}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-$((COUNT * 15 + 10))}"

echo "[scenario] Worker backlog and drain"
echo "[prefix] ${PREFIX}"
echo "[count] ${COUNT}"

docker compose down >/dev/null
docker compose up --build -d >/dev/null
ready=false
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS http://localhost:18121/health >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done
if [ "${ready}" != "true" ]; then
  echo "[error] order-api did not become ready"
  docker compose logs --tail=80 order-api
  exit 1
fi
docker compose stop order-worker >/dev/null

echo
echo "[1] Create multiple orders while worker is stopped"
for i in $(seq 1 "${COUNT}"); do
  req_id="${PREFIX}-${i}"
  curl -s -X POST \
    -H "x-request-id: ${req_id}" \
    http://localhost:18121/api/orders >/dev/null || true
  echo "created ${req_id}"
done

echo
echo "[2] Queue length before recovery"
docker compose exec -T redis redis-cli LLEN order-events

echo
echo "[3] Pending orders before recovery"
docker compose exec -T db psql -U paperclip -d paperclip \
  -c "select id, status, request_id, processed_at from orders where request_id like '${PREFIX}-%' order by id;"

echo
echo "[4] Start worker and observe drain"
docker compose start order-worker >/dev/null
for second in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  sleep 1
  printf "t+%ss queue_length=" "${second}"
  docker compose exec -T redis redis-cli LLEN order-events
done

echo
echo "[5] Wait until backlog is drained, max ${MAX_WAIT_SECONDS}s"
for second in $(seq 1 "${MAX_WAIT_SECONDS}"); do
  queue_length="$(docker compose exec -T redis redis-cli LLEN order-events | tr -d '\r')"
  printf "wait+%ss queue_length=%s\n" "${second}" "${queue_length}"
  if [ "${queue_length}" = "0" ]; then
    break
  fi
  sleep 1
done

echo
echo "[6] Orders after recovery"
docker compose exec -T db psql -U paperclip -d paperclip \
  -c "select id, status, request_id, processed_at from orders where request_id like '${PREFIX}-%' order by id;"
