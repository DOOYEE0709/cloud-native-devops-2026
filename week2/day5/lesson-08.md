# 8교시: Frontend + gateway + API + DB MSA preview template

> 실습 검증은 lab `week2/day5/labs/compose-architectures/07-frontend-gateway-api-db`(nginx gateway(정적+proxy) + PostgREST api + postgres db)로 진행했다. Day5의 종합편.

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker compose config --services` | service 3개 — `db`, `api`, `gateway` |
| `docker compose up -d` | network 3개(`public_net`/`app_net`/`data_net`)·volume(`pgdata`) 생성. `db` → `api` → `gateway` 순 기동 |
| `docker compose ps` | `gateway`만 `0.0.0.0:18091->80` 공개. `api`(`3000`)·`db`(`5432`)는 내부만 |
| `curl -s http://localhost:18091 \| grep week2-day5-msa-preview` | `week2-day5-msa-preview` — gateway가 정적 frontend 제공 |
| `curl -s http://localhost:18091/api/services` | `[{frontend,static client},{gateway,reverse proxy},{api,REST endpoint},{db,stateful backing service}]` — browser→gateway→api→db 전체 흐름 |
| `curl http://localhost:3000/services` (host 직접) | **접근 불가** — api는 host에 포트 미공개 |
| **`docker compose stop api`** 후 `/api/services` | **HTTP 504** — gateway가 죽은 api upstream 대기 timeout |
| 같은 상태 `/`(정적 frontend) | **HTTP 200** + `week2-day5-msa-preview` — gateway 자체와 정적은 정상 |
| `docker compose logs gateway` | `"GET /api/services HTTP/1.1" 504` — upstream 실패가 gateway log에 |
| `docker compose up -d api` 후 `/api/services` | **HTTP 200** 복구 |
| `docker compose down` | container 3개·network 3개 정리 (pgdata 보존) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 이 template은 무엇을 보여주나? | Day5 종합 — **frontend + gateway + API + DB**가 한 줄로 이어지는 최소 MSA preview. browser는 gateway(18091) 하나로 들어오고, gateway가 정적 화면 제공 + `/api/`를 내부 api로 proxy, api는 db에 붙는다. |
| 어느 교시들이 합쳐졌나? | 3교시(gateway가 정적+routing) + 5교시(`/api/` reverse proxy) + 7교시(PostgREST api+db). 지금까지 본 조각이 하나로 모인 구조다. |
| frontend는 별도 service인가? | 아니다. **gateway(nginx)가 정적 파일을 직접 제공**한다(`./frontend`를 document root로). frontend container가 따로 있는 게 아니라 gateway가 겸한다. |
| browser는 api에 직접 붙나? | 아니다. browser는 **gateway로만** 들어오고, gateway가 `/api/`를 `api:3000`으로 넘긴다. api는 host에 포트가 없어 직접 접근 불가. "frontend가 API에 직접 붙는다"가 아니라 "gateway를 거친다". |
| api가 죽으면 어떻게 되나? | `/api/`는 **504**, 정적 frontend(`/`)는 **200**. gateway는 살아있고 api dependency만 실패한다 — **failure propagation이 경계에서 멈춘다**(3·5교시 격리와 동일). 사용자는 "화면은 뜨는데 데이터만 안 옴"을 본다. |
| 외부 증상과 원인이 다를 수 있나? | 그렇다. 증상은 gateway에서 보이지만(504) 원인은 **api나 db**일 수 있다. gateway log로 "어느 upstream이 실패했나"를 보고 그 service부터 파고든다. |
| 이걸 Kubernetes로 옮기면? | gateway → Ingress/Service, api → Deployment/Service, db → StatefulSet/backing service. `depends_on`은 readiness/health check probe로, service name DNS는 k8s Service discovery로 바뀐다(Week 3). |

## notes

### Day5 종합 구조 — 한 줄로 이어지는 MSA preview

지금까지 본 조각들이 하나로 모였다. browser는 진입점 하나(gateway)로 들어와 정적 화면을 받고, 데이터는 `/api/`를 거쳐 api→db로 흐른다.

```text
browser → gateway(18091) ─┬─ /        → 정적 frontend (gateway가 직접 제공)
                          └─ /api/    → api:3000(PostgREST) ──db:5432──→ db(postgres)
```

| Service | 역할 | 공개 범위 | network |
|---|---|---|---|
| `gateway` | 정적 frontend 제공 + `/api/` reverse proxy (nginx) | host `18091` | `public_net`, `app_net` |
| `api` | PostgREST REST API | 내부 `3000`만 | `app_net`, `data_net` |
| `db` | PostgreSQL 16, init.sql 실행 | 내부 `5432`만 | `data_net` |

network가 3단 계층을 만든다: `gateway`(public+app) → `api`(app+data) → `db`(data). 각 service는 인접 layer만 안다 — gateway는 db를 모르고(data_net 없음), db는 외부를 모른다. **계층별 경계가 곧 traffic·장애 경계**다.

### 조각들의 종합 — 어느 교시가 어디에 들어갔나

| 이 lab의 부분 | 어느 교시 개념 |
|---|---|
| gateway가 정적 frontend 제공 | 3교시(gateway가 정적+API routing) |
| gateway `/api/` → api proxy_pass | 5교시(reverse proxy, service name upstream) |
| api(PostgREST) → db | 7교시(table을 REST로, service name `db` 연결) |
| api/db를 host에 안 염 | 2~7교시 공통(내부 service는 비공개) |
| `pgdata` volume | 2/7교시(DB data lifecycle) |

Day5 전체가 "이 한 구조를 이해하기 위한 준비"였던 셈이다.

### browser는 gateway로만, frontend는 gateway가 겸한다

핵심 오해 방지: **frontend container가 따로 없다.** gateway(nginx)가 `./frontend`를 document root로 마운트해 정적 파일을 직접 준다.

```nginx
location /     { root /usr/share/nginx/html; index index.html; }  # 정적 frontend
location /api/ { proxy_pass http://api:3000/; }                    # 내부 api로 proxy
```

그래서 browser 입장에서 화면도 데이터도 **전부 gateway(18091) 한 곳**으로 받는다. api는 host에 포트가 없어 `localhost:3000`으로 직접 못 붙는다 — 반드시 gateway의 `/api/`를 거친다. (실제 운영에선 frontend를 별도 SPA 서버/CDN로 빼기도 하지만, 이 lab은 최소 구조로 gateway가 겸한 것.)

### failure propagation — 경계에서 멈춘다 (실증)

`api`만 멈추고 확인:

| 요청 | api 중지 후 | 의미 |
|---|---|---|
| `/api/services` | **504** | gateway가 죽은 api upstream 대기 timeout |
| `/`(정적 frontend) | **200** | gateway 자체·정적은 정상 |

사용자는 **"화면은 뜨는데 데이터만 안 옴"** 을 본다. 장애가 api 경계에서 멈추고 frontend까지 안 번진다. gateway log에 `"GET /api/services" 504`가 남아 **어느 upstream이 실패했는지** 가리킨다.

> **304는 에러 아님 — 정적이 정상이라는 증거.** 브라우저로 `/`를 다시 열면 gateway log에 `"GET / HTTP/1.1" 304 0`이 찍힐 수 있다. **304 Not Modified = "안 바뀜, 캐시 그대로 써"** 라는 뜻(본문 0바이트). curl은 캐시가 없어 **200**(본문 전체)을 받지만, 브라우저는 이미 HTML을 캐시해뒀다가 조건부 요청(`If-None-Match`/`If-Modified-Since`)을 보내고, nginx가 파일이 안 바뀐 걸 확인하면 **304**로 캐시 재사용을 시킨다(대역폭 절약).
>
> ```text
> curl /     → 200  (캐시 없어 새로 받음)
> 브라우저 / → 304  (조건부 요청 → "안 바뀜, 캐시 써")   ← 둘 다 정적 정상
> ```
>
> 304가 떴다는 건 오히려 gateway가 멀쩡하다는 신호다(죽었으면 응답 없거나 5xx). failure drill 결론("api 504, 정적 정상")은 그대로 성립한다. (4교시 cache가 Redis/`staleTime`이었다면, 304는 **브라우저 HTTP 캐시** — `ETag`/`Last-Modified`로 변경 여부를 확인해 안 바뀌면 캐시를 재사용한다.)

dependency chain(gateway→api→db)에서 한 칸이 끊기면 그 아래만 영향받는다:

```text
db 죽음    → api도 응답 못 함 → /api/ 실패 (정적은 OK)
api 죽음   → /api/만 실패     (정적·gateway는 OK)  ← 이번 실증
gateway 죽음 → 전부 실패      (유일한 진입점이라 blast radius 최대)
```

gateway가 가장 위험한 단일 진입점이다(3교시 SPOF). 그래서 운영에선 gateway를 여러 대+LB로 둔다.

### 증상은 입구, 원인은 안쪽 — Day5 디버깅 원칙의 종합

외부에서 보이는 건 gateway의 status code지만, **원인은 chain 안쪽**일 수 있다. Day5 내내 반복된 원칙:

```text
curl   → 어느 path가 몇 번 코드로 실패하나 (증상)
logs gateway → 어느 upstream이 실패했나 (502/504 + upstream 주소)
logs api     → DB에 붙었나 (Successfully connected / Schema cache)
exec db / db-checker → 데이터·readiness (안쪽 원인)
```

504를 보고 gateway를 재시작하는 게 아니라, gateway log가 가리키는 **api → db 순으로 안쪽**을 본다.

### 트래픽/부하 성향 노트

| Service | 트래픽 성향 | CPU 부하 | 메모리/상태 부하 | 먼저 볼 것 |
|---|---|---|---|---|
| `gateway` | 모든 browser/API path 진입 | routing/compression/TLS | connection buffer | access/error log, upstream status |
| `api` | `/api/` 집중 | query 변환, JSON 생성 | DB connection 관리 | API status, latency |
| `db` | api dependency, stateful | query/index/transaction | volume, buffer/cache, connection | readiness, slow query |

트래픽이 늘면 gateway를 늘릴지/api를 늘릴지/db를 튜닝할지 판단한다. "어디가 public entrypoint인가"만으론 부족하고 CPU/메모리/connection pressure를 같이 본다(2·7교시 scale out 판단).

### DB가 느릴 때 — 인덱싱/쿼리 튜닝부터, 그 다음은 상황별

chain의 맨 안쪽 `db`가 병목일 때, **제일 먼저 보는 건 scale out이 아니라 인덱싱/쿼리 튜닝**이다. 가장 싸고(인프라 증설 0) 효과가 큰 경우가 많아서다. "느리다 → 서버 늘리자"보다 "느린 쿼리부터 잡자"가 순서다.

기본 단계 (싼 것 → 비싼 것):

| 단계 | 내용 | 비용/복잡도 |
|---|---|---|
| **① 인덱스/쿼리 튜닝** | slow query 찾기(`EXPLAIN`), 필요한 컬럼에 index 추가, N+1·풀스캔 제거 | 낮음 — **먼저 한다** |
| ② connection 관리 | pool size 조정, PgBouncer (2교시 곱셈 함정) | 낮음~중간 |
| ③ 캐시 | 읽기를 Redis로 흡수해 DB 도달 자체를 줄임 (4교시) | 중간 |
| ④ 읽기 복제본 | 읽기를 Replica로 분산 (7교시, 단 정합성/lag 고려) | 중간 |
| ⑤ 수직 확장 | 더 큰 DB 인스턴스(CPU/메모리) | 중간 (비용↑) |
| ⑥ 샤딩/파티셔닝 | 데이터를 쪼개 분산 | 높음 — 최후 수단 |

①을 먼저 하는 이유: index 하나로 풀스캔(O(n))이 인덱스 조회(O(log n))로 바뀌면 **서버 증설 없이** 수십~수백 배 빨라지기도 한다. 반대로 index가 부실한 채 ③~⑥을 해도 근본 병목이 남는다(2교시 "DB index 부실하면 API scale out만으로 해결 안 됨").

**개발 언어/프레임워크에 따라 달라지는 부분**: 기본(인덱싱)은 언어 무관하게 공통이지만, **ORM이 어떤 쿼리를 생성하느냐**는 언어/프레임워크마다 다르다(N+1 쿼리, lazy/eager loading 차이 등). 그래서 "느린 쿼리를 찾는 법·고치는 법"은 쓰는 스택에 따라 손대는 위치가 다를 수 있다.

**②~⑥은 상황별 선택**이다 — 읽기가 많으면 캐시/복제본, connection이 한계면 pooler, 데이터가 너무 크면 샤딩. 정답이 하나가 아니라 **병목의 정체에 맞춰** 고른다. 공통 원칙만 고정: **인덱싱/쿼리부터 보고, 그 다음은 측정해서 병목에 맞는 걸 고른다.**

### Week 3 다리 — Compose → Kubernetes

| Compose (Day5) | Kubernetes (Week 3) |
|---|---|
| `gateway` + `ports` | Ingress / Service (LoadBalancer) |
| `api` service | Deployment + Service |
| `db` + `pgdata` volume | StatefulSet + PersistentVolume (또는 관리형 DB) |
| service name DNS (`api`, `db`) | Service discovery (ClusterIP + DNS) |
| `depends_on` | readiness/liveness probe (순서가 아니라 상태) |
| `--scale api=3` | replicas, HPA(auto scaling) |

`depends_on`이 readiness probe로 바뀌는 게 큰 변화다 — Compose는 "순서 힌트"였지만(1교시), k8s는 "준비됐는지 상태를 계속 확인"한다.

### Cleanup 기준

```bash
docker compose down       # container + network 정리 (pgdata 보존)
docker compose down -v    # named volume pgdata까지 삭제
```

### 흔한 오해 / 실패

- frontend가 별도 container다 → gateway(nginx)가 정적 파일을 겸한다. 별도 frontend service 없음.
- browser가 api에 직접 붙는다 → gateway의 `/api/`를 거친다. api는 host 미공개.
- api 죽으면 화면도 안 뜬다 → 정적은 200, `/api/`만 504. 장애가 경계에서 멈춘다.
- 504면 gateway를 고친다 → gateway는 살아있고 upstream(api/db)이 원인. 안쪽부터 본다.

## Week 3 연결 질문

| 질문 | 왜 중요한가 |
|---|---|
| gateway가 죽으면 어떤 요청이 실패하는가 | 외부 진입점 장애 (blast radius 최대) |
| API가 죽으면 frontend는 어떻게 보이는가 | dependency failure (실증: 화면 OK, 데이터 504) |
| DB가 준비되기 전에 API가 뜨면 | readiness/health check (depends_on의 한계) |
| API를 2개로 늘리면 routing은 | scale out + connection pool 곱셈(2교시) |
| 이 Compose를 k8s manifest로 옮기면 | Week 3 bridge |

## Day 5 학습 서머리

| 배운 내용 | 설명할 수 있어야 하는 문장 |
|---|---|
| Compose 기본 루프 | `config`/`up`/`ps`/`logs`/`down`으로 template을 검증한다. |
| Network area | `public/app/cache/queue/data_net`을 나누면 traffic 경계와 service 역할이 보인다. |
| Service name DNS | container끼리는 `localhost`가 아니라 `db`/`redis`/`api`/`web-a` service name으로 만난다. |
| Port publish | host 접근 port와 container 내부 port는 다르다. 외부 진입점만 `ports`로 공개. |
| Volume lifecycle | DB data는 named volume에 남는다. `down`과 `down -v`는 다르다. |
| Gateway/proxy | browser는 gateway/proxy로 들어오고 내부 service는 직접 공개하지 않는다. |
| Cache/queue/worker | Redis는 별도 backing service, worker는 사용자 요청을 직접 안 받는다. |
| API + DB 검증 | API가 running이어도 schema/role/connection이 틀리면 정상이 아니다. |

답할 수 있어야 하는 질문:

```text
외부 traffic은 어디로 들어오는가?           → gateway(18091)
내부 service끼리 어떤 이름으로 만나는가?      → service name (api, db)
DB/cache/queue는 어느 network에 있는가?     → data_net / cache_net / queue_net
host에 공개하면 안 되는 service는?           → api, db, redis, worker (내부 전용)
실패하면 무엇을 먼저 보나?                   → curl(증상) → logs gateway(upstream) → logs api/db(원인)
이 구조를 k8s로 옮기면?                      → Ingress/Service/Deployment/StatefulSet + probe
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| `/api/`가 504, `/`(정적)는 200 | api upstream이 죽거나 응답 없음. `docker compose logs gateway`에서 `"GET /api/" 504` 확인 → api container 상태, 이어서 api→db 연결(`logs api`) 점검 |
| 화면도 안 뜸(`/`도 실패) | gateway 자체 문제(유일한 진입점). `docker compose ps`/`logs gateway`로 gateway 기동·설정(default.conf) 확인 |
| `/api/`가 빈 응답/DB 에러 | api는 떴지만 db 연결/schema 문제. 7교시처럼 `logs api`의 `Successfully connected`/`Schema cache`, init.sql 적용(pgdata stale 시 `down -v`) 확인 |
