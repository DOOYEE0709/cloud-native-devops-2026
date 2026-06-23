const http = require("http");

const port = Number(process.env.PORT || 3000);
const users = [
  { id: 1, nickname: "seoul-maker", trustScore: 91 },
  { id: 2, nickname: "market-helper", trustScore: 84 }
];

http.createServer((req, res) => {
  res.setHeader("content-type", "application/json; charset=utf-8");
  if (req.url === "/health") {
    res.end(JSON.stringify({ service: "identity-api", status: "ok" }));
    return;
  }
  if (req.url === "/users") {
    res.end(JSON.stringify({ service: "identity-api", users }));
    return;
  }
  res.statusCode = 404;
  res.end(JSON.stringify({ error: "not_found" }));
}).listen(port, "0.0.0.0", () => {
  console.log(`identity-api listening on ${port}`);
});
