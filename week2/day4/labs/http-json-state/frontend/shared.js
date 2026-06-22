function apiBase() {
  const params = new URLSearchParams(window.location.search);
  return params.get("api") || "http://localhost:18088";
}

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

