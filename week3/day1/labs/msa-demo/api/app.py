import json
import os
import socket
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DB_HOST = os.environ.get("DB_HOST", "db")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
SERVICE_NAME = os.environ.get("SERVICE_NAME", "api")


def db_reachable(timeout=1.5):
    started = time.time()
    try:
        with socket.create_connection((DB_HOST, DB_PORT), timeout=timeout):
            return True, round((time.time() - started) * 1000, 2), None
    except OSError as exc:
        return False, round((time.time() - started) * 1000, 2), str(exc)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        request_id = self.headers.get("x-request-id", "missing-request-id")
        print(json.dumps({
            "service": SERVICE_NAME,
            "request_id": request_id,
            "path": self.path,
            "message": fmt % args,
        }), flush=True)

    def write_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        request_id = self.headers.get("x-request-id", f"api-{int(time.time())}")
        ok, latency_ms, error = db_reachable()
        if self.path == "/health":
            self.write_json(200 if ok else 503, {
                "service": SERVICE_NAME,
                "ready": ok,
                "db_host": DB_HOST,
                "db_port": DB_PORT,
                "db_latency_ms": latency_ms,
                "error": error,
            })
            return
        if self.path == "/api/status":
            self.write_json(200 if ok else 503, {
                "service": SERVICE_NAME,
                "request_id": request_id,
                "frontend_to_api": "ok",
                "database_reachable": ok,
                "db_host": DB_HOST,
                "db_port": DB_PORT,
                "db_latency_ms": latency_ms,
                "error": error,
                "timestamp": int(time.time()),
            })
            return
        self.write_json(404, {"error": "not found", "path": self.path})


if __name__ == "__main__":
    print(json.dumps({"service": SERVICE_NAME, "event": "starting", "port": 8080}), flush=True)
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
