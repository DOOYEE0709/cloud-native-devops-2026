# 5교시: Compose로 전체 서비스 실행

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `cp .env.example .env` | runtime config 준비 (secret 실제값 아님, 예시값) |
| `docker compose up --build -d` | 이미지 빌드 + 전체 서비스 백그라운드 실행 |
| `docker compose ps` | frontend/api/worker/db 모두 Up, db healthy (api는 처음 `starting`일 수 있음) |
| `curl -s localhost:18083/api/status` | frontend 경유 API JSON, `database_reachable=true` 확인 |
| `curl -s localhost:18084/health` | API 직접 health 200, `ready=true` |
| `docker compose logs --tail=40 api worker` | request path/id, worker의 API 호출 status 200 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| `.env.example`은 무엇인가? | 어떤 runtime config가 필요한지 보여주는 예시 파일. secret 실제 운영 값을 넣는 파일이 아니다. `cp .env.example .env`로 복사해 사용. |
| `database_reachable=true`가 왜 중요한가? | 단순히 JSON이 온 것이 아니라 API가 DB까지 연결 가능하다는 증거다. JSON 응답 ≠ DB 정상. |
| 브라우저 화면이 뜨면 정상인가? | 아니다. 화면이 떠도 frontend 정적 파일만 정상일 수 있다. `/api/status`로 API·DB 연결까지 확인해야 한다. |
| baseline을 왜 수집하는가? | 정상 baseline이 있어야 Day2에서 장애 전파·부분 장애를 비교할 수 있다. |

## notes

### 실행 전 준비

```bash
cd week3/day1/labs/msa-demo
cp .env.example .env
cat .env.example
```

| 값 | 의미 |
|---|---|
| `POSTGRES_PASSWORD` | local practice DB password |
| `DB_HOST` | API가 DB를 찾을 service name |
| `DB_PORT` | DB container internal port |

`.env.example`은 필요한 config를 보여주는 파일이고, secret 실제값을 넣는 파일이 아니다. (3교시 secret 외부 관리와 연결)

### 실행

```bash
docker compose up --build -d
docker compose ps
```

```text
NAME                  SERVICE    STATUS
msa-demo-frontend-1   frontend   Up
msa-demo-api-1        api        Up (health: starting 또는 healthy)
msa-demo-worker-1     worker     Up
msa-demo-db-1         db         Up (healthy)
```

처음엔 API health가 `starting`일 수 있다 — healthcheck interval과 DB readiness 때문에 잠깐 기다린다.

### --build 캐시 vs --force-recreate (무엇이 반영 안 될 때)

"바꿨는데 적용 안 됨"은 원인이 두 종류다 — **이미지 빌드** 문제와 **컨테이너 재생성** 문제. 도구가 다르다.

**`--build` = 이미지 다시 만들기.** `up`은 기본적으로 이미지가 있으면 재사용해서, `build:` service(api/worker)의 코드를 고쳐도 재빌드 안 하면 옛 코드로 실행된다.

```bash
docker compose up -d           # 이미지 재사용 → 코드 변경 반영 X
docker compose up --build -d   # 재빌드 → 코드 변경 반영 O
```

**`--build`도 레이어 캐시를 쓴다.** 가끔 캐시가 옛 결과를 재사용하면 강제로 무시:

```bash
docker compose build --no-cache   # 캐시 무시 처음부터 빌드
docker compose up -d
```

**`.env`는 캐시 문제가 아니다.** environment 값은 이미지에 안 구워지고 container 생성 시 주입된다. 빌드 캐시와 무관하고, 안 바뀌는 건 "container를 다시 안 만들어서". → `--force-recreate`로 재생성:

```bash
docker compose up -d --force-recreate
```

**bind mount 파일**(index.html, nginx.conf)은 이미지에 안 들어가고 호스트와 직접 연결 → 저장 즉시 반영. 단 nginx 설정은 한 번 읽으면 끝이라 `docker compose restart frontend` 필요할 수 있음.

| 무엇을 바꿨나 | 반영 방법 |
|---|---|
| api/worker 코드, Dockerfile | `up --build -d` |
| `--build`인데도 옛 결과 남음 | `build --no-cache` → `up -d` |
| `.env` / environment 값 | `up -d --force-recreate` (캐시 아님, 재생성 문제) |
| bind mount 파일(index.html 등) | 저장 즉시 반영, nginx는 `restart` |

한 줄: 코드 → `--build`(필요시 `--no-cache`), `.env` → `--force-recreate`. 원인이 이미지 빌드 vs 컨테이너 재생성으로 다르다.

### 정상 baseline 수집

```bash
curl -s http://localhost:18083/api/status   # frontend 경유
curl -s http://localhost:18084/health       # API 직접
docker compose logs --tail=40 api
docker compose logs --tail=40 worker
```

`/api/status` 예상 응답:

```json
{
  "service": "api",
  "frontend_to_api": "ok",
  "database_reachable": true,
  "db_host": "db",
  "db_port": 5432
}
```

`database_reachable=true` = API가 DB까지 연결 가능하다는 증거. (JSON이 온 것만으로는 부족)

### baseline 표

| 확인 | 명령 | 정상 기준 |
|---|---|---|
| Compose 상태 | `docker compose ps` | frontend/api/worker/db 모두 Up, db healthy |
| frontend 경유 API | `curl localhost:18083/api/status` | JSON 응답, `database_reachable=true` |
| API 직접 health | `curl localhost:18084/health` | 200, `ready=true` |
| API 로그 | `docker compose logs api` | request path와 request id |
| worker 로그 | `docker compose logs worker` | API 호출 status 200 |

### 흔한 실패

| 증상 | 원인 후보 | 첫 확인 |
|---|---|---|
| `port is already allocated` | 18083 또는 18084 사용 중 | `docker ps` |
| API health 503 | DB 미준비 또는 DB_HOST 오류 | `docker compose logs api db` |
| frontend 502 | nginx가 api에 연결 실패 | `docker compose logs frontend api` |
| worker error 반복 | API URL 오류 또는 API 중지 | `docker compose logs worker` |

### Cleanup 기준

실습 도중에는 바로 지우지 않는다. **Day2에서도 같은 앱을 쓰기 때문.**

```bash
docker compose down       # 컨테이너만 정리 (DB data 유지)
docker compose down -v    # DB data(volume)까지 초기화 — 주의
```

### 핵심

MSA 실습에서 baseline은 선택이 아니다. 정상 baseline이 있어야 Day2에서 장애 전파와 부분 장애를 비교할 수 있다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
