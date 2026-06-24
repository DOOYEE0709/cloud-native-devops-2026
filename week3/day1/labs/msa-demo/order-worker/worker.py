import json
import os
import time

import psycopg
import redis

SERVICE_NAME = os.environ.get("SERVICE_NAME", "order-worker")
DB_DSN = os.environ.get("DB_DSN", "postgresql://paperclip:paperclip-local-only@db:5432/paperclip")
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
QUEUE_NAME = os.environ.get("QUEUE_NAME", "order-events")


def log(event, request_id, **fields):
    print(json.dumps({
        "service": SERVICE_NAME,
        "event": event,
        "request_id": request_id,
        **fields,
    }, ensure_ascii=False), flush=True)


def ensure_schema():
    with psycopg.connect(DB_DSN) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                create table if not exists audit_logs (
                    id serial primary key,
                    service_name text not null,
                    request_id text,
                    event text not null,
                    details jsonb not null default '{}'::jsonb,
                    created_at timestamptz default now()
                )
            """)
        conn.commit()


def process_order(order_id, request_id):
    ensure_schema()
    with psycopg.connect(DB_DSN) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "update orders set status='processed', processed_at=now() where id=%s",
                (order_id,),
            )
            cur.execute(
                """
                insert into audit_logs(service_name, request_id, event, details)
                values (%s, %s, 'order_processed', %s::jsonb)
                """,
                (SERVICE_NAME, request_id, json.dumps({"order_id": order_id})),
            )
        conn.commit()


ensure_schema()
client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
log("starting", "system", redis=REDIS_HOST, queue=QUEUE_NAME)

while True:
    try:
        _, payload = client.brpop(QUEUE_NAME, timeout=5)
        event = json.loads(payload)
        request_id = event.get("request_id", f"worker-{int(time.time())}")
        order_id = event["order_id"]
        log("order_event_received", request_id, order_id=order_id)
        process_order(order_id, request_id)
        log("order_processed", request_id, order_id=order_id)
    except TypeError:
        log("queue_idle", f"worker-{int(time.time())}", queue=QUEUE_NAME)
    except Exception as exc:
        log("worker_error", f"worker-{int(time.time())}", error=str(exc))
        time.sleep(3)
