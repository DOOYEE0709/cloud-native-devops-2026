# 6교시: 서비스 간 통신 확인

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `curl -s -H 'x-request-id: w3d1-front-001' localhost:18083/api/status` | frontend→api 경유, JSON에 `request_id`, `frontend_to_api`, `database_reachable` 확인 |
| `docker compose logs --tail=80 api \| grep w3d1-front-001` | 전달한 request id로 api 로그에서 요청 추적 |
| `curl -i localhost:18084/health` | api→db, `200 OK` + `ready=true`, `db_host=db` |
| `docker compose logs --tail=80 worker` | worker→api, `status: 200` 로그 확인 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| api container에서 `db_host`가 `localhost`가 아니라 `db`인 이유는? | container 입장에서 `localhost`는 자기 자신이다. DB는 별도 container라 service name `db`로 찾아야 한다. |
| worker가 `http://localhost:8080`을 쓰면? | 실패한다. worker container의 localhost는 worker 자신이라 api에 닿지 못한다. `http://api:8080`을 써야 한다. |
| `grep`에 `\|\| true`를 붙인 이유와 주의점은? | request id가 없을 때도 실습 흐름을 잇기 위해서. 단 실제 장애 분석에서 무조건 붙이면 실패를 숨길 수 있다. |
| 통신 확인은 "curl 한 번 성공"이면 되는가? | 아니다. 사용자 경로·service 내부 경로·background 경로를 나눠 각각의 증거를 잡아야 한다. |

## notes

### 흐름 1: frontend → api

```bash
curl -s -H 'x-request-id: w3d1-front-001' http://localhost:18083/api/status
docker compose logs --tail=80 api | grep w3d1-front-001 || true
```

| JSON key | 의미 |
|---|---|
| `service` | 실제 응답한 service는 api |
| `request_id` | frontend가 전달한 request id |
| `frontend_to_api` | frontend 경유 요청 성공 표시 |
| `database_reachable` | API가 DB까지 연결 가능한지 |

`|| true`는 request id가 없어도 실습을 잇기 위함. 실제 장애 분석에선 실패를 숨길 수 있어 주의.

### 흐름 2: api → db

```bash
curl -i http://localhost:18084/health
```

```text
HTTP/1.0 200 OK
```
```json
{ "ready": true, "db_host": "db", "db_port": 5432, "error": null }
```

`db_host`가 `localhost`가 아니라 `db`인 점이 핵심. **API container 입장에서 `localhost`는 API 자기 자신**이다.

### 흐름 3: worker → api

worker는 host port가 없으니 curl 대신 로그로 확인한다.

```bash
docker compose logs --tail=80 worker
```
```json
{ "service": "worker", "request_id": "worker-...", "api_url": "http://api:8080/api/status", "status": 200 }
```

worker가 `http://localhost:8080`을 쓰면 실패 — container 내부 localhost는 worker 자신이기 때문.

### host 기준과 container 기준

| 관점 | 주소 예시 | 사용 상황 |
|---|---|---|
| host → frontend | `http://localhost:18083` | browser/curl로 사용자 경로 확인 |
| host → api debug | `http://localhost:18084` | 강의에서 API health 직접 확인 |
| frontend → api | `http://api:8080` | nginx reverse proxy 내부 통신 |
| api → db | `db:5432` | API container 내부 DB 연결 |
| worker → api | `http://api:8080/api/status` | background service 통신 |

**localhost 함정**: container 안에서 `localhost`는 항상 그 container 자신. 다른 service는 반드시 service name(`api`, `db`)으로 찾아야 한다.

### 장애 넣기 전, 정상 경로 4문장

```text
사용자 요청은 localhost:18083으로 들어온다.
frontend container는 api:8080으로 요청을 넘긴다.
api는 db:5432로 PostgreSQL 연결을 확인한다.
worker는 api:8080/api/status를 주기적으로 호출한다.
```

이 네 문장을 말하지 못하면 장애 분석은 운에 맡기는 일이 된다.

### 핵심

MSA의 통신 확인은 "curl 한 번 성공"이 아니다. 사용자 경로, service 내부 경로, background 경로를 나눠 각각의 증거를 잡는 것이다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
