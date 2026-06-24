import json
import os
import time
import urllib.request

API_URL = os.environ.get("API_URL", "http://api:8080/api/status")
INTERVAL = int(os.environ.get("WORKER_INTERVAL_SECONDS", "8"))

while True:
    request_id = f"worker-{int(time.time())}"
    try:
        req = urllib.request.Request(API_URL, headers={"x-request-id": request_id})
        with urllib.request.urlopen(req, timeout=3) as response:
            body = response.read().decode("utf-8")
            print(json.dumps({
                "service": "worker",
                "request_id": request_id,
                "api_url": API_URL,
                "status": response.status,
                "body_preview": body[:140],
            }), flush=True)
    except Exception as exc:
        print(json.dumps({
            "service": "worker",
            "request_id": request_id,
            "api_url": API_URL,
            "error": str(exc),
        }), flush=True)
    time.sleep(INTERVAL)
