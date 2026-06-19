const http = require("http");

const port = Number(process.env.PORT || 8080);
const appEnv = process.env.APP_ENV || "missing";
const dbHost = process.env.DB_HOST || "missing";
const dbPort = process.env.DB_PORT || "missing";

function sendJson(res, payload, status = 200) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(body),
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  console.log("backend-log", req.method, req.url);

  if (req.url === "/" || req.url === "/health") {
    sendJson(res, { status: "ok", message: "hello from node backend" });
    return;
  }

  if (req.url === "/api/info" || req.url === "/info") {
    sendJson(res, {
      service: "node-backend",
      message: "hello world",
      app_env: appEnv,
      db_host: dbHost,
      db_port: dbPort,
    });
    return;
  }

  sendJson(res, { error: "not found", path: req.url }, 404);
});

server.listen(port, "0.0.0.0", () => {
  console.log(`node backend listening on ${port}`);
});
