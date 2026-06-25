#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../../../day1/labs/msa-demo"

REQ_ID="${REQ_ID:-day2-duplicate-$(date +%s)}"

echo "[scenario] Duplicate request without idempotency key"
echo "[request_id] ${REQ_ID}"

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
echo "[1] Send the same request id twice"
curl -s -X POST -H "x-request-id: ${REQ_ID}" http://localhost:18121/api/orders >/dev/null || true
curl -s -X POST -H "x-request-id: ${REQ_ID}" http://localhost:18121/api/orders >/dev/null || true
for second in $(seq 1 35); do
  queue_length="$(docker compose exec -T redis redis-cli LLEN order-events | tr -d '\r')"
  printf "wait+%ss queue_length=%s\n" "${second}" "${queue_length}"
  if [ "${queue_length}" = "0" ]; then
    break
  fi
  sleep 1
done

echo
echo "[2] Orders with same request_id"
docker compose exec -T db psql -U paperclip -d paperclip \
  -c "select id, status, request_id, created_at, processed_at from orders where request_id='${REQ_ID}' order by id;"

echo
echo "[3] Audit rows with same request_id"
docker compose exec -T db psql -U paperclip -d paperclip \
  -c "select service_name, request_id, event, details, created_at from audit_logs where request_id='${REQ_ID}' order by id;"

echo
echo "[4] Queue length after duplicate processing"
docker compose exec -T redis redis-cli LLEN order-events

echo
echo "[5] Worker logs for duplicate request"
docker compose logs --tail=120 order-worker | grep "${REQ_ID}" || true

echo
echo "[note] Same request_id does not prevent duplicates. Real APIs need an idempotency key or unique request boundary."
