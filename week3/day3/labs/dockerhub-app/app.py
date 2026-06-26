import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


APP_VERSION = os.environ.get("APP_VERSION", "0.1.0")
SERVICE_NAME = os.environ.get("SERVICE_NAME", "w3d3-dockerhub-app")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(json.dumps({
            "service": SERVICE_NAME,
            "event": "http_access",
            "path": self.path,
            "message": fmt % args,
        }), flush=True)

    def write_json(self, status, payload):
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path in ["/", "/health"]:
            self.write_json(200, {
                "service": SERVICE_NAME,
                "version": APP_VERSION,
                "status": "ok",
            })
            return
        self.write_json(404, {"error": "not found", "path": self.path})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    print(json.dumps({
        "service": SERVICE_NAME,
        "event": "starting",
        "port": port,
        "version": APP_VERSION,
    }), flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
