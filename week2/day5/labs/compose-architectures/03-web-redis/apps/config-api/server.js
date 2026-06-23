const http = require("http");

const port = Number(process.env.PORT || 3000);
const config = {
  service: "config-api",
  apiBaseUrl: process.env.API_BASE_URL || "http://localhost:18101",
  featureFlags: {
    newCheckout: process.env.FEATURE_NEW_CHECKOUT === "true",
    aiReview: process.env.FEATURE_AI_REVIEW === "true"
  }
};

http.createServer((req, res) => {
  res.setHeader("content-type", "application/json; charset=utf-8");
  if (req.url === "/health") {
    res.end(JSON.stringify({ service: "config-api", status: "ok" }));
    return;
  }
  if (req.url === "/config") {
    res.end(JSON.stringify(config));
    return;
  }
  res.statusCode = 404;
  res.end(JSON.stringify({ error: "not_found" }));
}).listen(port, "0.0.0.0", () => {
  console.log(`config-api listening on ${port}`);
});
