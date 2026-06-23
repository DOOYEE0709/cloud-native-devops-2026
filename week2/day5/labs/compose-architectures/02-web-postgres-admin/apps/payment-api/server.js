const http = require("http");

const port = Number(process.env.PORT || 3000);
const payments = [
  { id: "pay-1001", userId: 1, amount: 39000, status: "approved" },
  { id: "pay-1002", userId: 2, amount: 12000, status: "pending" }
];

http.createServer((req, res) => {
  res.setHeader("content-type", "application/json; charset=utf-8");
  if (req.url === "/health") {
    res.end(JSON.stringify({ service: "payment-api", status: "ok" }));
    return;
  }
  if (req.url === "/payments") {
    res.end(JSON.stringify({ service: "payment-api", payments }));
    return;
  }
  res.statusCode = 404;
  res.end(JSON.stringify({ error: "not_found" }));
}).listen(port, "0.0.0.0", () => {
  console.log(`payment-api listening on ${port}`);
});
