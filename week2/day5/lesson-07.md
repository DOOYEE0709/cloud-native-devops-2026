# 7교시: API + PostgreSQL template

> 실습 검증은 lab `week2/day5/labs/compose-architectures/06-api-postgrest`(PostgREST api + postgres db + db-checker)로 진행했다.

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker compose config --services` | service 3개 — `db`, `api`, `db-checker` |
| `docker compose up -d` | network 2개(`public_net`/`data_net`)·volume(`pgdata`) 생성. `db` → `api`/`db-checker` 순 기동 |
| `docker compose ps` | `api`만 `0.0.0.0:18090->3000` 공개. `db`/`db-checker`는 내부 `5432`만 |
| `curl -s http://localhost:18090/tasks` | `[{"id":1,"title":"read compose.yaml","status":"done"},{"id":2,"title":"call api service by published port","status":"todo"}]` — `api.tasks` table이 REST로 노출 |
| `curl 'http://localhost:18090/tasks?status=eq.done'` | `[{"id":1,...,"status":"done"}]` — PostgREST **필터링**(`status=eq.done`) |
| `curl 'http://localhost:18090/tasks?select=title'` | `[{"title":"read compose.yaml"},{"title":"..."}]` — **컬럼 선택**(`select=title`) |
| `curl http://localhost:18090/nonexistent` | **HTTP 404** + `{"code":"42P01",...,"message":"relation \"api.nonexistent\" does not exist"}` — 없는 table은 PostgreSQL 에러코드 그대로 |
| `curl http://localhost:18090/` | **HTTP 200** — root는 OpenAPI 스펙 자동 제공 |
| `docker compose logs api` | `Successfully connected to PostgreSQL 16.14 ...` + `Schema cache loaded 1 Relations` — API가 DB에 붙어 schema를 읽음 |
| `docker compose logs db-checker` | `db:5432 - accepting connections` 후 `api.tasks` 2행 조회 (service name `db`로 접속) |
| `docker compose down` | container 3개·network 2개 정리 (pgdata 보존) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 이 template은 무엇을 보여주나? | DB table을 **별도 코드 없이 REST API로 노출**하는 가장 짧은 API+DB 구조. PostgREST가 `api` schema의 table(`tasks`)을 자동으로 `GET /tasks` 같은 endpoint로 만든다. |
| 2교시(01-web-postgres)와 뭐가 다른가? | 거의 같은 PostgREST+postgres인데, 2교시는 **frontend(nginx)가 앞에** 있었고 여기는 **frontend 없이 API+DB만**. table도 `products`가 아니라 `tasks`. "frontend와 DB 사이 API layer"의 본질만 남긴 것. |
| API는 DB에 어떻게 붙나? | `PGRST_DB_URI: postgres://app_user:app_password@db:5432/app` — host가 service name `db`다(2교시와 동일 원리). API 로그의 `Successfully connected to PostgreSQL`이 실제 연결 증거. |
| PostgREST가 table을 API로 바꾸는 원리는? | `PGRST_DB_SCHEMAS: api`가 노출할 schema, `PGRST_DB_ANON_ROLE: web_anon`이 익명 요청에 부여할 role. `api.tasks` → `GET /tasks`. init.sql에서 `web_anon`에 `select`만 줬다. |
| "API가 떴다"와 "DB에 붙었다"는 같은가? | 다르다. `api` container가 `Up`이어도 schema/role/connection string이 틀리면 endpoint는 실패한다. 그래서 `ps`(떴나)만 보지 말고 `curl`(응답하나) + `logs api`(연결됐나) + `logs db-checker`(데이터 있나)를 같이 본다. |
| 없는 table을 부르면? | **404** + PostgreSQL 에러(`42P01 relation "api.nonexistent" does not exist`). PostgREST가 DB 에러를 그대로 전달한다 — API가 죽은 게 아니라 "그 resource가 schema에 없다"는 뜻. |
| `?status=eq.done` 같은 건 뭔가? | PostgREST의 query 문법. URL parameter로 **필터(`eq.`/`gt.` 등)·정렬·컬럼선택(`select=`)** 을 한다. SQL을 직접 안 짜도 table을 REST로 조회할 수 있다. |

## notes

### 핵심 구조 — table을 코드 없이 REST API로

PostgREST는 **DB schema를 읽어 자동으로 REST API를 만들어주는** 도구다. 컨트롤러/라우터 코드를 한 줄도 안 쓰고 `api.tasks` table이 `GET /tasks`가 된다.

```text
browser → api(18090, PostgREST) ──db:5432──→ db(postgres)
          GET /tasks  →  SELECT * FROM api.tasks  (자동 변환)
```

| Service | 역할 | 공개 범위 | network |
|---|---|---|---|
| `api` | DB table → REST API (PostgREST) | host `18090` | `public_net`, `data_net` |
| `db` | PostgreSQL 16, init.sql 실행 | 내부 `5432`만 | `data_net` |
| `db-checker` | DB readiness/초기데이터 확인 | logs만 | `data_net` |

`api`가 `public_net`(외부 확인)과 `data_net`(DB 연결) 둘 다에 속하는 중간 layer다(2교시 catalog-api와 동일 패턴).

### PostgREST 설정 3가지가 endpoint를 결정한다

| env | 역할 |
|---|---|
| `PGRST_DB_URI` | 어느 DB에 어떤 계정으로 붙나 — host가 service name `db` |
| `PGRST_DB_SCHEMAS: api` | 어느 schema를 노출하나 — `api` schema의 table만 endpoint가 됨 |
| `PGRST_DB_ANON_ROLE: web_anon` | 익명 요청에 부여할 DB role — 이 role의 권한이 곧 API 권한 |

권한이 곧 API다: init.sql에서 `grant select on api.tasks to web_anon`만 했으니 **읽기만** 된다. 쓰기(POST/PATCH)는 web_anon 권한이 없어 막힌다. **DB role/grant가 API 보안의 경계**가 된다.

### "API가 떴다" ≠ "DB에 붙었다" — 확인을 나눠서

이 lab의 핵심 교훈. container가 `Up`이어도 endpoint가 동작한다는 보장이 없다.

```text
docker compose ps        → "api container가 떴나" (프로세스)
curl /tasks              → "endpoint가 응답하나" (실제 동작)
docker compose logs api  → "DB에 붙고 schema를 읽었나" (Successfully connected / Schema cache loaded)
docker compose logs db-checker → "DB에 데이터가 있나"
```

API 로그의 `Successfully connected to PostgreSQL` + `Schema cache loaded 1 Relations`가 "진짜 연결됐다"는 증거다. schema/role/connection string이 틀리면 container는 떠도 이 로그가 안 나오거나 endpoint가 빈 응답/에러를 준다. **`ps`의 `Up`을 성공으로 착각하지 않는 것**이 1교시부터 이어진 원칙이다.

### 없는 resource는 404 + DB 에러 그대로

```text
GET /nonexistent → 404 {"code":"42P01", "message":"relation \"api.nonexistent\" does not exist"}
```

`42P01`은 PostgreSQL의 "undefined table" 에러코드다. PostgREST가 **DB 에러를 그대로 전달**한다. 이건 API가 죽은 게(5xx) 아니라 "그 resource가 schema에 없다"는 정상적인 404다. (5교시 502/504, 3교시 404 구분처럼 — status code가 원인을 가리킨다.)

> root(`/`)는 200으로 **OpenAPI 스펙**을 자동 제공한다. PostgREST가 schema에서 API 문서까지 만들어준다.

### scale out이 DB pressure를 키운다 — 2교시 연결

API + DB 구조의 성능 한계는 보통 API가 아니라 **DB query와 connection**에서 드러난다. API container를 여러 개로 늘리면 DB connection도 같이 는다.

```text
api 1대 (pool N) → api 10대 → DB connection 10×N  (2교시 connection pool 곱셈 함정)
```

API가 REST 요청을 아무리 빨리 받아도, DB가 connection 한계·slow query에 막히면 전체가 느려진다. **scale out 전에 "병목이 API CPU인가 DB인가"** 를 본다(2교시와 동일 결론). PostgREST는 가벼워서 보통 DB가 먼저 한계다.

### 읽기 복제본과 정합성 — Primary/Replica

DB가 읽기 병목일 때 흔한 해법: **쓰기는 Primary 하나, 읽기는 Replica 여러 개**로 분산한다(읽기 많은 커머스/조회 서비스).

```text
쓰기 → [Primary DB] ──복제(replication)──→ [Replica DB] ← 읽기
       (master)                         (read replica)
```

문제는 복제가 **즉시가 아니라 지연(replication lag)** 이 있다는 것. lag이 크면 stale read가 난다:

```text
1. 사용자가 글 작성 → Primary에 씀
2. 곧바로 새로고침 → Replica에서 읽음
3. 아직 복제 전 → "내가 쓴 게 없네?" (옛 데이터 = stale read, read-after-write 깨짐)
```

"1초 언더로 동기화돼야 한다"는 건 이 lag을 사람이 못 느낄 만큼 짧게 유지하자는 **서비스 요구사항**이다(서비스마다 허용치 다름). 복제본 간 일치 = **정합성(consistency)** 문제이고, 더 정확히는 **복제 지연으로 인한 stale read / eventual consistency** 문제다.

| 정합성 모델 | 뜻 | 대가 |
|---|---|---|
| strong consistency | 쓰면 즉시 모든 읽기에 반영 | 동기 복제 → **쓰기 느려짐** |
| eventual consistency | "결국엔" 일치, 잠깐 어긋남 가능 | 쓰기 빠름, **stale read 가능** |

Primary/Replica 비동기 복제는 보통 eventual consistency다. 깨질 때 막는 법: 중요한 읽기(결제 직후 조회)는 **Primary에서**, read-your-writes 라우팅, 필요시 동기 복제(쓰기 지연 감수), replication lag 모니터링·알람.

> ACID의 'C(Consistency)'는 또 다른 의미(트랜잭션 전후 무결성 규칙 유지)라 헷갈린다. 분산 복제 맥락의 정합성은 "복제본 간 일치"를 가리킨다.

### 트래픽/부하 성향 노트

| Service | 트래픽 성향 | CPU 부하 | 메모리/상태 부하 | 먼저 볼 것 |
|---|---|---|---|---|
| `api` | REST 요청 집중 | JSON 변환, role/schema 처리 | connection 관리 | HTTP status, API log |
| `db` | table read/write 집중 | join/filter/sort | buffer/cache, table/index, WAL | slow query, connection 수 |
| `db-checker` | readiness 확인 | 거의 없음 | 없음 | DB 준비 증거 |

### Cleanup 기준

```bash
docker compose down       # container + network 정리 (pgdata 보존)
docker compose down -v    # named volume pgdata까지 삭제 — tasks 데이터 삭제
```

`db`에 `pgdata` volume이 있어 `down`만으론 데이터가 남는다. init.sql을 다시 적용하려면 `down -v`(2교시 stale volume 원리).

### 흔한 오해 / 실패

- container가 `Up`이면 API 정상 → schema/role/connection이 틀리면 떠도 endpoint 실패. logs로 연결 확인.
- API에 붙이려면 코드를 짜야 한다 → PostgREST는 schema를 읽어 자동 생성. table = endpoint.
- 없는 endpoint = 서버 에러 → 404 + DB 에러(`42P01`). API가 죽은 게 아니라 resource가 없는 것.
- API scale out하면 빨라진다 → DB가 병목이면 connection만 늘어 더 나빠질 수 있다(2교시).

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| `api`는 `Up`인데 `/tasks`가 빈 응답/에러 | `docker compose logs api`에서 `Successfully connected` / `Schema cache loaded`가 있는지 확인 → 없으면 `PGRST_DB_URI`(service name `db`), schema, role 점검. db-checker로 데이터 유무 확인 |
| `/<resource>`가 404 `42P01` | 그 table이 `api` schema에 없거나 이름 오타. init.sql 적용 여부(pgdata stale 시 `down -v`) 확인 |
