import json
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import psycopg
from psycopg.rows import dict_row

SERVICE_NAME = os.environ.get("SERVICE_NAME", "catalog-api")
DB_DSN = os.environ.get("DB_DSN", "postgresql://paperclip:paperclip-local-only@db:5432/paperclip")


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
        conn.commit()


def query_products():
    ensure_schema()
    with psycopg.connect(DB_DSN, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            cur.execute("select id, name, price, stock from products order by id")
            return cur.fetchall()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        request_id = self.headers.get("x-request-id", "missing-request-id")
        log("http_access", request_id, path=self.path, message=fmt % args)

    def write_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        request_id = self.headers.get("x-request-id", f"catalog-{int(time.time())}")
        if self.path == "/health":
            try:
                products = query_products()
                self.write_json(200, {"service": SERVICE_NAME, "ready": True, "product_count": len(products)})
            except Exception as exc:
                self.write_json(503, {"service": SERVICE_NAME, "ready": False, "error": str(exc)})
            return

        if self.path == "/api/catalog/products":
            try:
                products = query_products()
                log("products_listed", request_id, count=len(products))
                self.write_json(200, {"service": SERVICE_NAME, "request_id": request_id, "products": products})
            except Exception as exc:
                log("products_failed", request_id, error=str(exc))
                self.write_json(503, {"service": SERVICE_NAME, "request_id": request_id, "error": str(exc)})
            return

        self.write_json(404, {"error": "not found", "path": self.path})


if __name__ == "__main__":
    ensure_schema()
    log("starting", "system", port=8081)
    ThreadingHTTPServer(("0.0.0.0", 8081), Handler).serve_forever()
