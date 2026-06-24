# 8교시: 구름 EXP 배움일기 - MSA 토폴로지와 연결 실패 증거

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker compose ps` | service별 Up/healthy 상태 |
| `curl -s localhost:18083/api/status` | `frontend_to_api`, `database_reachable` |
| `curl -s localhost:18084/health` | `ready`, `db_host`, `error` |
| `docker compose logs --tail=60 api` | request path, request id |
| `docker compose logs --tail=60 worker` | `api_url`, status 또는 error |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 오늘의 구조를 한 문장으로? | 사용자는 `localhost:18083`으로 들어오고 frontend가 `api:8080`으로 넘기며, api는 `DB_HOST=db`로 PostgreSQL에 붙는다. worker는 host port 없이 `api:8080/api/status`를 호출한다. |
| 가장 헷갈린 지점은? | container 내부에서 `localhost`가 왜 자기 자신을 가리키는지. 다른 service는 service name(`api`, `db`)으로 찾아야 한다. |
| 장애 시 무엇을 먼저 의심했나? | 사용자 증상에서 시작해 dependency map을 따라감. frontend 502면 api, `/health` 503이면 DB 연결을 먼저 의심. |
| Day1 완료 기준은? | MSA 용어 암기가 아니라, service contract로 요청·dependency를 설명하고 실패 시 어느 service의 어떤 증거를 먼저 볼지 말할 수 있는 것. |

## notes

### Day1 학습 서머리

오늘은 MSA를 "서비스를 작게 나누는 개발 방식"이 아니라 **"여러 실행 단위를 운영하는 구조"** 로 봤다.

| 배운 내용 | 설명할 수 있어야 하는 문장 |
|---|---|
| Monolith vs MSA | MSA는 독립 배포를 가능하게 하지만 network dependency와 운영 비용을 만든다 |
| Service contract | service별 image/build, port, env, dependency, health, logs를 표로 정리해야 한다 |
| frontend 경로 | browser는 `localhost:18083`으로 들어오고 frontend가 `api:8080`으로 넘긴다 |
| API readiness | API process가 살아 있어도 DB 연결이 실패하면 `/health`는 실패할 수 있다 |
| worker 경로 | worker는 host port가 없고 내부에서 `api:8080/api/status`를 호출한다 |
| DB dependency | API는 `DB_HOST=db`, `DB_PORT=5432`로 PostgreSQL에 붙는다 |
| 장애 증거 | API 중지, DB 중지, DB_HOST 오류는 서로 다른 로그와 status를 만든다 |

### 남겨야 할 Evidence

출력 전체가 아니라 핵심 줄만 정리한다.

```bash
docker compose config
docker compose ps
curl -s http://localhost:18083/api/status
curl -s http://localhost:18084/health
docker compose logs --tail=60 api
docker compose logs --tail=60 worker
```

### Day2로 넘길 질문

| 질문 | Day2 연결 |
|---|---|
| API가 running인데 `/health`가 503이면 장애인가 | readiness |
| worker가 실패해도 사용자는 정상일 수 있는가 | 부분 장애 |
| retry를 많이 하면 항상 좋은가 | timeout/retry |
| 여러 service 로그를 어떻게 이어 볼 것인가 | correlation id |
| Compose의 `depends_on`은 Kubernetes에서 무엇으로 바뀌는가 | readiness probe |

### Cleanup

Day2에서 같은 앱을 바로 쓸 수 있으므로 환경에 따라 유지하거나 정리한다.

```bash
docker compose down       # 정리 (DB data 유지)
docker compose down -v    # DB volume까지 초기화
```

### 핵심

Day1 완료 기준은 MSA라는 말을 외우는 것이 아니다. `msa-demo`의 service contract를 보고 **사용자 요청과 내부 dependency를 설명하며, 실패했을 때 어느 service의 어떤 증거를 먼저 볼지 말할 수 있어야** 한다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
