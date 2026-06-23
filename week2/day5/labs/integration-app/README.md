# Week 2 Day 5 Integration App

## Purpose
이 앱은 Week 2 Day 5 통합 실습용 표준 정적 웹 앱이다. 목표는 새 기능 개발이 아니라 Dockerfile, image build, tag, run, Compose, security note, cleanup, README handoff를 하나의 증거 묶음으로 닫는 것이다.

## File Map
| Path | Purpose |
|---|---|
| `Dockerfile` | nginx 기반 image build 기준 |
| `.dockerignore` | build context에서 제외할 파일 기준 |
| `compose.yaml` | local Compose 실행 기준 |
| `html/index.html` | HTTP body marker를 제공하는 정적 파일 |
| `README.md` | start/check/cleanup/handoff 기준 |

## Build
```bash
docker build -t paperclip/week2-day5-integration:local .
```

Expected:

```text
Successfully tagged paperclip/week2-day5-integration:local
```

## Run
```bash
docker run -d \
  --name paperclip-day5-web \
  -p 18085:80 \
  paperclip/week2-day5-integration:local
```

## Check
```bash
docker ps --filter name=paperclip-day5-web
for i in 1 2 3 4 5; do
  curl -I http://localhost:18085 && break
  sleep 1
done
curl -s http://localhost:18085 | grep week2-day5-integration-v1
docker logs paperclip-day5-web
```

Expected:

```text
0.0.0.0:18085->80/tcp
HTTP/1.1 200 OK
week2-day5-integration-v1
```

## Compose
```bash
docker compose config
docker compose up -d
docker compose ps
for i in 1 2 3 4 5; do
  curl -I http://localhost:18085 && break
  sleep 1
done
curl -s http://localhost:18085 | grep week2-day5-integration-v1
```

## Tag Flow
```bash
docker tag paperclip/week2-day5-integration:local paperclip/week2-day5-integration:v1
docker images paperclip/week2-day5-integration
```

Do not push to a public registry unless the instructor explicitly asks for it and the image contains no secrets or private data.

## Cleanup
```bash
docker rm -f paperclip-day5-web
docker compose down
```

Optional local image cleanup:

```bash
docker image rm paperclip/week2-day5-integration:local
docker image rm paperclip/week2-day5-integration:v1
```

## Security Notes
- Do not copy `.env`, credentials, tokens, SSH keys, or personal files into the image.
- Keep `.dockerignore` small but meaningful.
- Use explicit image tags for 확인 지점.
- Do not treat `latest` as enough 확인 지점 for a class submission.
- Do not publish an image before checking its contents and README.

## 주의할 점 체크리스트
- [ ] `docker build` completed.
- [ ] local image tag exists.
- [ ] `docker run` served HTTP 200.
- [ ] body marker `week2-day5-integration-v1` was observed.
- [ ] `docker compose config` passed.
- [ ] `docker compose up -d` served the same app.
- [ ] cleanup command was run.
- [ ] README includes run/check/cleanup.
