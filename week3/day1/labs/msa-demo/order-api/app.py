import json
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import psycopg
import redis
from psycopg.rows import dict_row

SERVICE_NAME = os.environ.get("SERVICE_NAME", "order-api")
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
                create table if not exists products (
                    id serial primary key,
                    name text not null,
                    price integer not null,
                    stock integer not null default 0,
                    created_at timestamptz default now()
                )
            """)
            cur.execute("""
                create table if not exists customers (
                    id serial primary key,
                    name text not null,
                    email text not null unique,
                    created_at timestamptz default now()
                )
            """)
            cur.execute("""
                create table if not exists orders (
                    id serial primary key,
                    customer_id integer references customers(id),
                    status text not null default 'pending',
                    total_price integer not null default 0,
                    request_id text,
                    created_at timestamptz default now(),
                    processed_at timestamptz
                )
            """)
            cur.execute("""
                create table if not exists order_items (
                    id serial primary key,
                    order_id integer references orders(id),
                    product_id integer references products(id),
                    quantity integer not null default 1,
                    unit_price integer not null
                )
            """)
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
            cur.execute("""
                insert into products(name, price, stock)
                values
                    ('msa-starter-kit', 39000, 15),
                    ('observability-notebook', 22000, 30),
                    ('kubernetes-preview-card', 18000, 20)
            """)
            cur.execute("""
                delete from products a
                using products b
                where a.id > b.id and a.name = b.name
            """)
            cur.execute("""
                insert into customers(name, email)
                values ('Paperclip Student', 'student@example.com')
                on conflict (email) do nothing
            """)
        conn.commit()


def redis_client():
    return redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)


def create_order(request_id):
    ensure_schema()
    with psycopg.connect(DB_DSN, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            cur.execute("select id, price from products order by id limit 1")
            product = cur.fetchone()
            cur.execute("select id from customers order by id limit 1")
            customer = cur.fetchone()
            cur.execute(
                """
                insert into orders(customer_id, status, total_price, request_id)
                values (%s, 'pending', %s, %s)
                returning id, status, total_price, request_id, created_at
                """,
                (customer["id"], product["price"], request_id),
            )
            order = cur.fetchone()
            cur.execute(
                """
                insert into order_items(order_id, product_id, quantity, unit_price)
                values (%s, %s, 1, %s)
                """,
                (order["id"], product["id"], product["price"]),
            )
            cur.execute(
                """
                insert into audit_logs(service_name, request_id, event, details)
                values (%s, %s, 'order_created', %s::jsonb)
                """,
                (SERVICE_NAME, request_id, json.dumps({"order_id": order["id"]})),
            )
        conn.commit()
    redis_client().lpush(QUEUE_NAME, json.dumps({"order_id": order["id"], "request_id": request_id}))
    return order


def list_orders():
    ensure_schema()
    with psycopg.connect(DB_DSN, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            cur.execute("select id, status, total_price, request_id, created_at, processed_at from orders order by id desc limit 10")
            return cur.fetchall()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        request_id = self.headers.get("x-request-id", "missing-request-id")
        log("http_access", request_id, path=self.path, message=fmt % args)

    def write_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False, indent=2, default=str).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        request_id = self.headers.get("x-request-id", f"order-{int(time.time())}")
        if self.path == "/health":
            try:
                redis_client().ping()
                list_orders()
                self.write_json(200, {"service": SERVICE_NAME, "ready": True, "redis": REDIS_HOST, "queue": QUEUE_NAME})
            except Exception as exc:
                self.write_json(503, {"service": SERVICE_NAME, "ready": False, "error": str(exc)})
            return
        if self.path == "/api/orders":
            try:
                orders = list_orders()
                log("orders_listed", request_id, count=len(orders))
                self.write_json(200, {"service": SERVICE_NAME, "request_id": request_id, "orders": orders})
            except Exception as exc:
                log("orders_failed", request_id, error=str(exc))
                self.write_json(503, {"service": SERVICE_NAME, "request_id": request_id, "error": str(exc)})
            return
        self.write_json(404, {"error": "not found", "path": self.path})

    def do_POST(self):
        request_id = self.headers.get("x-request-id", f"order-{int(time.time())}")
        if self.path == "/api/orders":
            try:
                order = create_order(request_id)
                log("order_created", request_id, order_id=order["id"], queue=QUEUE_NAME)
                self.write_json(201, {"service": SERVICE_NAME, "request_id": request_id, "queued": True, "order": order})
            except Exception as exc:
                log("order_create_failed", request_id, error=str(exc))
                self.write_json(503, {"service": SERVICE_NAME, "request_id": request_id, "error": str(exc)})
            return
        self.write_json(404, {"error": "not found", "path": self.path})


if __name__ == "__main__":
    ensure_schema()
    log("starting", "system", port=8082, redis=REDIS_HOST, queue=QUEUE_NAME)
    ThreadingHTTPServer(("0.0.0.0", 8082), Handler).serve_forever()
