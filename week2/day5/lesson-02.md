# 2교시: 쿠팡형 커머스 카탈로그 template

> 실습 검증은 lab `week2/day5/labs/compose-architectures/01-web-postgres`(nginx frontend + PostgREST catalog-api + postgres db + db-checker)로 진행했다.

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker compose config --services` | service 4개 확인 — `db`, `db-checker`, `catalog-api`, `frontend` |
| `docker compose config` (정규화) | `depends_on`이 `condition: service_started`로 확장, `ports`가 `published: "18101"/"18085"`, `protocol: tcp`로 풀림, `./html` bind volume이 절대경로(`/Users/.../01-web-postgres/html`)로 표시됨 |
| `docker compose up -d` | network 3개(`app_net`/`data_net`/`public_net`)·volume(`pgdata`)·container 4개 생성. `db` → `catalog-api`/`db-checker` → `frontend` 순으로 기동. 이번엔 18085 충돌 없이 전부 `Started` |
| `docker compose ps` | 4개 모두 `Up`. `frontend`(`0.0.0.0:18085->80`), `catalog-api`(`0.0.0.0:18101->3000`), `db`/`db-checker`는 내부 `5432`만 (host 미공개) |
| `docker compose logs db-checker` | `db:5432 - no response` → `db:5432 - accepting connections` 후 `SELECT id, name, stock FROM api.products`로 상품 3행 조회 성공. service name `db`로 접속 |
| `curl -sI http://localhost:18085` | `HTTP/1.1 200 OK`, `Server: nginx/1.27.5`, `Content-Length: 294` — frontend 정적 페이지 응답 |
| `curl -s http://localhost:18085 \| grep` | body에 마커 `company-commerce-catalog` 확인 |
| `curl -s http://localhost:18101/products` | PostgREST(`catalog-api`)가 `PGRST_DB_URI=...@db:5432/app`로 DB에 붙어 상품 3건 JSON 반환 |
| `docker compose exec -T db psql -U postgres -d app -c "SELECT current_database();"` | `app` 반환 — `POSTGRES_DB: app`로 초기화된 DB 확인 |
| `docker compose down -v` | container 4개·network 3개·named volume `pgdata`까지 삭제 (실습이라 데이터 삭제 허용) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 이 template은 무엇을 줄인 구조인가? | W1D4의 커머스 아키텍처를 frontend(nginx) + catalog API(PostgREST) + products DB(PostgreSQL) 3덩어리로 줄인 것. 화면은 하나처럼 보여도 뒤에 상품 API와 상품 DB가 분리돼 있다. |
| host port와 container internal port는 어떻게 다른가? | host 접근은 published port(`18085`, `18101`)로 한다. service 간 접근은 container port로 한다 — `catalog-api`는 DB를 `db:5432`(container port 5432)로 찾고, host의 18101이 아니다. `ps`에서 `db`는 host port가 안 보이는데, `data_net` 내부에서만 5432로 쓰이기 때문이다. |
| `catalog-api`는 DB를 어떻게 찾는가? | `localhost`가 아니라 service name `db`로 찾는다. `PGRST_DB_URI: postgres://app_user:app_password@db:5432/app`의 host가 `db`다. Compose project network(`data_net`) 안에서 service name이 DNS로 동작한다. |
| `db-checker`는 왜 있는가? | service name 기반 DB 연결을 logs로 보여주는 수업용 보조 service. `until pg_isready -h db ...; do sleep 1; done`로 DB ready를 기다린 뒤 `api.products`를 조회한다. host에 아무 port도 안 열고 logs만으로 "연결됐다"는 증거를 남긴다. |
| 왜 `db`는 host port를 공개하지 않는가? | DB는 외부 진입점이 아니다. `data_net`에만 두고 host로 노출하지 않는다. 접근이 필요한 `catalog-api`/`db-checker`만 같은 `data_net`에 붙어 service name으로 만난다. (`frontend`는 `data_net`에 없어 DB에 직접 못 붙는다.) |
| products 데이터는 어떻게 들어갔나? | `db/init.sql`이 `/docker-entrypoint-initdb.d/`에 마운트돼 **pgdata가 비어 있을 때 최초 1회** 실행. `web_anon`/`app_user` role과 `api.products` table을 만들고 상품 3행을 insert한다. 그래서 `down -v`로 volume을 비워야 init이 다시 돈다. |
| PostgREST가 table을 API로 바꾸는 원리는? | `api` schema(`PGRST_DB_SCHEMAS: api`)의 table을 자동으로 REST endpoint로 노출한다. `api.products` → `GET /products`. 익명 접근은 `web_anon` role(`PGRST_DB_ANON_ROLE`)로 처리되고, init.sql에서 `web_anon`에 `select` 권한만 줬다. |

## notes

### 그림의 연결선이 Compose에서 어떻게 표현되는가

읽는 순서는 `frontend → catalog-api → db`. W1D4 아키텍처 그림의 화살표가 Compose에서는 다음으로 바뀐다.

| 그림의 연결선 | Compose 표현 |
|---|---|
| browser → frontend | `frontend.ports: "18085:80"` (public 진입점) |
| frontend → catalog API | `frontend.depends_on: catalog-api` + 같은 `app_net` |
| catalog API → DB | `PGRST_DB_URI: ...@db:5432/app` (service name `db`) + 같은 `data_net` |
| DB의 상태 보존 | named volume `pgdata:/var/lib/postgresql/data` |

연결선을 외우는 게 아니라 **어느 service가 어느 network에 속하고, 누가 누구를 service name으로 부르는지** 읽는 것이 핵심이다.

### 4개 service의 역할과 공개 범위

| Service | 역할 | 공개 범위 | network |
|---|---|---|---|
| `frontend` | nginx static web (상품 화면) | host `18085` | `public_net`, `app_net` |
| `catalog-api` | products table REST API (PostgREST) | host `18101` | `app_net`, `data_net` |
| `db` | PostgreSQL 16 (products 저장) | 내부 `5432`만 | `data_net` |
| `db-checker` | DB 연결 확인용 보조 | logs만 | `data_net` |

`catalog-api`가 `app_net`과 `data_net` **둘 다**에 속하는 게 포인트다 — 위로는 frontend(`app_net`), 아래로는 db(`data_net`)와 만나는 중간 layer다. `frontend`는 `data_net`에 없어서 DB에 직접 못 붙고 반드시 API를 거친다. network 분리가 "누가 누구에게 직접 닿을 수 있는가"를 구조로 강제한다.

### host port vs service name DNS — 이 lab의 핵심 한 줄

```text
host에서 나(사람)는      → localhost:18085 (frontend), localhost:18101/products (API)
container에서 API는 DB를 → db:5432  (service name, host port 아님)
```

같은 "5432"라도 의미가 다르다. `db`는 host에 5432를 안 열었지만(`ps`에서 host port 없음), `catalog-api`와 `db-checker`는 `data_net` 안에서 `db:5432`로 잘 붙는다. **published port는 host↔container, container port는 container↔container.** 이 구분이 안 되면 "왜 catalog-api는 localhost:18101이 아니라 db:5432를 쓰지?"에서 막힌다.

### db-checker가 보여주는 readiness vs 순서

`db-checker` 로그가 `db:5432 - no response` → `accepting connections`로 바뀌는 게 그대로 readiness 증거다.

```text
depends_on: db   → "db를 먼저 시작하라" (순서 힌트, condition: service_started)
pg_isready -h db → "db가 연결을 받을 준비가 됐는지" (readiness)
```

`depends_on`은 container 시작 순서만 보장하지, DB가 쿼리를 받을 준비가 됐다는 뜻이 아니다. 그래서 `db-checker`가 `until pg_isready ...; do sleep 1; done`로 직접 기다린 뒤 쿼리한다. (1교시에서 정리한 원리의 실증.)

### init.sql은 pgdata가 비어 있을 때만 최초 1회

상품 3행이 들어간 출처는 `db/init.sql`이다. `/docker-entrypoint-initdb.d/01-init.sql`은 PostgreSQL 데이터 디렉토리(=`pgdata` volume)가 **비어 있을 때만** 실행된다.

```text
init.sql 수정 → docker compose up → 안 먹음 (pgdata에 이미 데이터 있음)
docker compose down -v → up        → 빈 pgdata에 init 재실행
```

상품 목록을 바꾸려고 `init.sql`을 고쳤는데 반영이 안 되면 거의 항상 이 stale volume 문제다. (1교시 "설정 바꿨는데 안 먹을 때"와 같은 원리.)

### 트래픽/부하 성향 노트

커머스 카탈로그는 읽기(상품 목록·검색·상세 조회)가 압도적으로 많다. read path가 핵심.

| Service | 트래픽 성향 | CPU 부하 | 메모리/상태 부하 | 먼저 볼 것 |
|---|---|---|---|---|
| `frontend` | 정적 파일 요청 집중 | 낮음(gzip/TLS 붙이면 증가) | 낮음 | access log, 4xx/5xx |
| `catalog-api` | 상품 조회 API 집중 | query 변환·JSON 생성 시 증가 | connection pool 설정 영향 | API latency, error log |
| `db` | read query 반복 | 정렬/필터/인덱스 부재 시 증가 | buffer/cache, table/index size | slow query, connection 수 |

실무에선 catalog API를 scale out하거나 앞에 cache를 붙인다. **다만 DB index가 부실하면 API를 늘려도 DB가 병목이라 해결되지 않는다** — 먼저 DB read path부터 본다.

### scale out의 함정 — connection pool이 곱셈으로 늘어난다

"API가 느리니 서버를 늘리자"가 **DB를 죽이는** 대표 사례다. catalog-api는 보통 DB connection을 매 요청마다 새로 열지 않고 **connection pool**(미리 열어둔 연결 묶음)을 들고 있다. 문제는 이 pool이 **instance마다 따로** 존재한다는 것이다.

```text
catalog-api 1대  × pool 10 =  10 connections
오토스케일링으로 10대로 증가 → 10대 × pool 10 = 100 connections  (의도치 않게 10배)
```

instance 수를 늘린 만큼 DB로 가는 연결 총량도 곱해진다. 그런데 PostgreSQL은 **connection 하나당 메모리(work_mem 등 backend process)** 를 쓰기 때문에 `max_connections`라는 상한이 있다(기본 100 근처). 위 예에서 100개를 다 열면 DB는 이미 한계다.

상한을 넘으면 이렇게 무너진다.

| 단계 | 일어나는 일 |
|---|---|
| connection이 `max_connections`에 도달 | DB가 새 연결을 거부 — `FATAL: sorry, too many clients already` |
| catalog-api가 DB 연결 실패 | 요청 처리 불가 → 5xx, 응답 지연 |
| (잘못 만든 경우) 연결 실패가 app crash로 | health check 실패 → container 재시작 루프 → 더 많은 재연결 시도로 악화 |
| 오토스케일링이 "느리다"고 판단 | instance를 **더** 늘림 → connection 총량 **더** 증가 → DB 더 압박 (악순환) |

핵심 역설: **scale out이 문제를 키운다.** instance를 늘릴수록 connection 총량이 늘어 DB 한계를 더 세게 때린다. CPU 부족이면 scale out이 답이지만, **DB connection 한계가 병목일 땐 scale out이 독**이다.

막는 방법:

| 방법 | 무엇을 하나 |
|---|---|
| instance당 pool size 작게 | `instance 수 × pool size ≤ max_connections` 여유 있게 유지 |
| connection pooler (PgBouncer 등) | app과 DB 사이에 두고 수많은 app 연결을 소수의 실제 DB 연결로 **다중화**. instance가 늘어도 DB 연결 총량은 pooler가 통제 |
| DB `max_connections` 조정 | 메모리가 받쳐줄 때만. 무작정 늘리면 메모리 부족으로 DB 자체가 위험 |
| cache로 DB 도달 자체를 줄임 | 읽기 traffic을 Redis 등에서 흡수 (4교시 cache 주제로 연결) |

정리: scale out 전에 "이 병목이 CPU인가 DB connection인가"를 먼저 본다. connection이 병목이면 instance가 아니라 **pooler/pool size/cache**를 손대야 한다. (위 부하 노트에서 `catalog-api`의 "connection pool 설정 영향", `db`의 "connection 수"가 바로 이 지점이다.)

### frontend CPU 부담(TLS/gzip)은 운영에서 어디로 옮기나

부하 노트에서 frontend는 "gzip/TLS 붙이면 CPU 증가"라고 적었다. 운영에서는 이 부담을 frontend instance가 직접 지지 않고 **AWS 관리형 계층으로 offload**한다. 일이 사라지는 게 아니라 **옮겨지고 비용을 내는** 것이다.

무엇이 CPU를 먹나:

| 작업 | 왜 CPU를 먹나 |
|---|---|
| TLS (HTTPS) | handshake의 키 교환 + 데이터 암복호화. 연결 수가 많을수록 누적 |
| gzip | 응답 본문을 매번 압축. 본문이 크고 요청이 많을수록 부담 |

어디로 옮기나:

| 계층 | TLS termination | gzip/brotli 압축 | 엣지 캐싱 |
|---|---|---|---|
| ALB | O (ACM 인증서) | **X** (압축 안 함) | X |
| CloudFront (CDN) | O | O (자동) | O |
| S3 + CloudFront (정적이면) | O | O | O — origin 거의 안 때림 |

핵심 구분:

```text
ALB        : TLS termination O,  gzip 압축 X
CloudFront : TLS termination O,  gzip/brotli O,  엣지 캐싱 O
```

- **TLS termination(오프로딩)**: 클라이언트 ↔ AWS 구간만 HTTPS로 받고 AWS가 TLS를 풀어 뒤의 nginx로는 평문 HTTP(또는 가벼운 재암호화)로 전달. nginx는 handshake/암복호화 CPU를 안 쓴다. 인증서는 ACM이 자동 갱신.
- **gzip은 ALB가 아니라 CloudFront 영역**이다. 압축까지 넘기려면 CDN을 쓴다.
- 이 lab처럼 **정적 frontend면 nginx를 안 쓰고 S3 + CloudFront**로 서빙할 수 있다. 캐시 hit는 엣지에서 끝나 origin CPU 자체가 거의 안 쓰인다.

단서:
- 요즘 CPU는 AES-NI 하드웨어 가속이 있어 TLS 부담이 예전만큼 크진 않다. gzip이 상대적으로 더 CPU-bound.
- TLS handshake는 연결마다 새 임시 키(ephemeral, forward secrecy)를 만들어 CPU를 쓰는데, **session ticket**(정해진 수명 동안 세션 재사용)으로 풀 handshake 횟수를 줄여 CPU를 아낀다. 티켓이 만료되면 다시 풀 handshake. 인증서 유효기간(달/년 단위, ACM 자동 갱신)과는 다른 층이다.

### Cleanup 기준

```bash
docker compose down       # container + network 정리 (pgdata 데이터 보존)
docker compose down -v    # named volume pgdata까지 삭제 — 상품 데이터 삭제
```

`down -v`는 상품 데이터 삭제다. init.sql을 다시 적용하고 싶을 때(또는 깨끗이 초기화할 때)만 쓴다.

### 흔한 오해 / 실패

- `catalog-api`도 `localhost`로 DB에 붙는다 → service name `db`로 붙는다. `localhost`는 container 자기 자신.
- `db`도 host port가 있어야 한다 → DB는 진입점이 아니라 `data_net` 내부 service. host 노출 불필요.
- `init.sql`을 고치면 바로 반영된다 → pgdata가 이미 있으면 안 돈다. `down -v` 필요.
- `frontend`에서 DB를 직접 조회한다 → `frontend`는 `data_net`에 없다. 반드시 API를 거친다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| (1교시) `frontend` 18085 port 충돌 가능 | 다른 lab이 18085를 점유 중이면 `frontend`만 실패하고 나머지는 정상 기동. 이번 실행에선 충돌 없이 4개 모두 `Up`. 충돌 시 `docker compose ps`/`logs frontend`로 어느 service가 실패했는지 확인 |
