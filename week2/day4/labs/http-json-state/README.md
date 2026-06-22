# HTTP 200 vs JSON Contract Lab

이 lab은 `container Up`, `HTTP 200`, `frontend 정상 렌더링`이 서로 다른 확인 기준임을 보여준다.

## 실행
repository root에서 실행한다.

```bash
docker rm -f paperclip-day4-api paperclip-day4-frontend || true
docker run -d --name paperclip-day4-api \
  -p 18088:8080 \
  -e RESPONSE_MODE=text \
  -v "$PWD/week2/day4/labs/http-json-state/backend:/app:ro" \
  -w /app \
  python:3.12-alpine python app.py

docker run -d --name paperclip-day4-frontend \
  -p 18087:80 \
  -v "$PWD/week2/day4/labs/http-json-state/frontend:/usr/share/nginx/html:ro" \
  nginx:1.27-alpine
```

## 확인
```bash
curl -i http://localhost:18088/health
curl -i http://localhost:18088/api/items
docker logs paperclip-day4-api --tail 20
```

브라우저:

```text
http://localhost:18087/ok.html
http://localhost:18087/items.html
```

`ok.html`은 200 OK를 정상으로 보여준다. `items.html`은 `/api/items`를 JSON으로 파싱하려고 하므로 `RESPONSE_MODE=text`에서는 실패한다.

## 복구
```bash
docker rm -f paperclip-day4-api
docker run -d --name paperclip-day4-api \
  -p 18088:8080 \
  -e RESPONSE_MODE=json \
  -v "$PWD/week2/day4/labs/http-json-state/backend:/app:ro" \
  -w /app \
  python:3.12-alpine python app.py
```

다시 확인한다.

```bash
curl -i http://localhost:18088/api/items
docker logs paperclip-day4-api --tail 20
```

`items.html`을 새로고침하면 list가 렌더링된다.

## Cleanup
```bash
docker rm -f paperclip-day4-api paperclip-day4-frontend
```

