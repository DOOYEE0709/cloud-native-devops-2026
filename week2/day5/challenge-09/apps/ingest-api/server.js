const http = require("http");
const net = require("net");

const port = Number(process.env.PORT || 3000);
const redisHost = process.env.REDIS_HOST || "redis-queue";
const redisPort = Number(process.env.REDIS_PORT || 6379);

// RESP 인코딩으로 redis에 명령 전송 (라이브러리 없이 raw TCP)
function encode(args) {
  return `*${args.length}\r\n` + args.map((a) => `$${Buffer.byteLength(String(a))}\r\n${a}\r\n`).join("");
}
function redisCommand(args) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection(redisPort, redisHost);
    let data = "";
    socket.on("connect", () => socket.write(encode(args)));
    socket.on("data", (chunk) => { data += chunk.toString(); socket.end(); });
    socket.on("end", () => resolve(data.trim()));
    socket.on("error", reject);
  });
}

http.createServer(async (req, res) => {
  res.setHeader("content-type", "application/json; charset=utf-8");
  try {
    if (req.url === "/health") {
      res.end(JSON.stringify({ service: "ingest-api", status: "ok" }));
      return;
    }
    if (req.url.startsWith("/ingest")) {
      const url = new URL(req.url, "http://localhost");
      const event = url.searchParams.get("event") || "click:demo";
      const result = await redisCommand(["LPUSH", "events", event]);  // queue에 적재
      res.end(JSON.stringify({ service: "ingest-api", queued: event, redis: result }));
      return;
    }
    res.statusCode = 404;
    res.end(JSON.stringify({ error: "not_found" }));
  } catch (e) {
    res.statusCode = 500;
    res.end(JSON.stringify({ error: e.message }));
  }
}).listen(port, "0.0.0.0", () => console.log(`ingest-api listening on ${port}`));
