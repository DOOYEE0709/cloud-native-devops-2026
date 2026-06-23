const http = require("http");
const net = require("net");

const port = Number(process.env.PORT || 3000);
const redisHost = process.env.REDIS_HOST || "queue";
const redisPort = Number(process.env.REDIS_PORT || 6379);

function encode(args) {
  return `*${args.length}\r\n` + args.map((arg) => `$${Buffer.byteLength(String(arg))}\r\n${arg}\r\n`).join("");
}

function redisCommand(args) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection(redisPort, redisHost);
    let data = "";
    socket.on("connect", () => socket.write(encode(args)));
    socket.on("data", (chunk) => {
      data += chunk.toString();
      socket.end();
    });
    socket.on("end", () => resolve(data.trim()));
    socket.on("error", reject);
  });
}

http.createServer(async (req, res) => {
  res.setHeader("content-type", "application/json; charset=utf-8");
  try {
    if (req.url === "/health") {
      res.end(JSON.stringify({ service: "message-api", status: "ok" }));
      return;
    }
    if (req.url.startsWith("/publish")) {
      const url = new URL(req.url, "http://localhost");
      const job = url.searchParams.get("job") || "send-push:demo";
      const result = await redisCommand(["LPUSH", "jobs", job]);
      res.end(JSON.stringify({ service: "message-api", queued: job, redis: result }));
      return;
    }
    res.statusCode = 404;
    res.end(JSON.stringify({ error: "not_found" }));
  } catch (error) {
    res.statusCode = 500;
    res.end(JSON.stringify({ error: error.message }));
  }
}).listen(port, "0.0.0.0", () => {
  console.log(`message-api listening on ${port}`);
});
