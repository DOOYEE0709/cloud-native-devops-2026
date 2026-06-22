import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer


ITEMS = [
    {"id": 1, "name": "runtime config"},
    {"id": 2, "name": "logs evidence"},
    {"id": 3, "name": "json contract"},
]


class Handler(BaseHTTPRequestHandler):
    def _send(self, status, content_type, body):
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, fmt, *args):
        mode = os.getenv("RESPONSE_MODE", "text")
        print(f"path={self.path} mode={mode} client={self.client_address[0]} " + fmt % args, flush=True)

    def do_GET(self):
        mode = os.getenv("RESPONSE_MODE", "text")

        if self.path == "/health":
            self._send(200, "text/plain; charset=utf-8", "OK")
            return

        if self.path == "/api/items":
            if mode == "json":
                payload = json.dumps({"items": ITEMS}, ensure_ascii=False)
                self._send(200, "application/json; charset=utf-8", payload)
                return

            self._send(200, "text/plain; charset=utf-8", "OK")
            return

        self._send(404, "text/plain; charset=utf-8", "not found")


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    print(f"backend listening on 0.0.0.0:{port} RESPONSE_MODE={os.getenv('RESPONSE_MODE', 'text')}", flush=True)
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()

