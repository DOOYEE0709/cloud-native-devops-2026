#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../../../day1/labs/msa-demo"

PAYLOAD="${PAYLOAD:-not-json-day2-poison-$(date +%s)}"

echo "[scenario] Poison message without DLQ"
echo "[payload] ${PAYLOAD}"

docker compose down >/dev/null
docker compose up --build -d >/dev/null
for _ in 1 2 3 4 5; do
  if docker compose exec -T redis redis-cli PING >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

queue_length="$(docker compose exec -T redis redis-cli LLEN order-events | tr -d '\r')"
if [ "${queue_length}" != "0" ]; then
  echo "[precondition failed] order-events queue is not empty: ${queue_length}"
  echo "Run this scenario after the queue is drained, or inspect the current backlog first."
  exit 1
fi

before_audit_id="$(
  docker compose exec -T db psql -U paperclip -d paperclip -At \
    -c "select coalesce(max(id), 0) from audit_logs;" | tr -d '\r'
)"

echo
echo "[1] Push malformed queue message"
docker compose exec -T redis redis-cli LPUSH order-events "${PAYLOAD}"

echo
echo "[2] Worker consumes it and logs an error"
sleep 15
docker compose logs --tail=80 order-worker | grep -E "worker_error|${PAYLOAD}" || true

echo
echo "[3] Queue length after poison message"
docker compose exec -T redis redis-cli LLEN order-events

echo
echo "[4] Audit rows created after poison message"
docker compose exec -T db psql -U paperclip -d paperclip \
  -c "select service_name, request_id, event, created_at from audit_logs where id > ${before_audit_id} order by id;"

echo
echo "[note] In this teaching worker, malformed messages are consumed and lost. A real system needs DLQ/retry metadata."
