#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../../../day1/labs/msa-demo"

REQ_ID="${REQ_ID:-day2-ghost-pending-$(date +%s)}"

echo "[scenario] Redis down during order creation"
echo "[request_id] ${REQ_ID}"

echo
echo "[1] Start stack"
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

echo
echo "[2] Stop Redis before order request"
docker compose stop redis >/dev/null

echo
echo "[3] Client request while Redis is down"
curl -i -s -X POST \
  -H "x-request-id: ${REQ_ID}" \
  http://localhost:18121/api/orders || true

echo
echo "[4] Order row may already exist even when client saw failure"
docker compose exec -T db psql -U paperclip -d paperclip \
  -c "select id, status, request_id, created_at, processed_at from orders where request_id='${REQ_ID}' order by id;"

echo
echo "[5] Recover Redis"
docker compose start redis >/dev/null
sleep 3

echo
echo "[6] Queue length after Redis recovery"
docker compose exec -T redis redis-cli LLEN order-events

echo
echo "[7] Audit rows for this request"
docker compose exec -T db psql -U paperclip -d paperclip \
  -c "select service_name, request_id, event, created_at from audit_logs where request_id='${REQ_ID}' order by id;"

echo
echo "[cleanup] Keep stack usable"
docker compose start order-worker >/dev/null
