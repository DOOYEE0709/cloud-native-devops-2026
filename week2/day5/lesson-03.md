# 3교시: 당근형 백엔드 서비스 경계 template

> 실습 검증은 lab `week2/day5/labs/compose-architectures/02-web-postgres-admin`(nginx gateway + identity-api/payment-api(node) + postgres db + adminer + db-checker)로 진행했다.

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker compose config --services` | service 6개 — `db`, `adminer`, `db-checker`, `identity-api`, `payment-api`, `gateway` |
| `docker compose up -d` | network 3개(`app_net`/`data_net`/`public_net`)·volume(`pgdata`)·container 6개 생성. `db`/api들 먼저, `gateway`/`adminer`가 뒤에 기동 |
| `docker compose ps` | `gateway`(`0.0.0.0:18086->80`), `adminer`(`0.0.0.0:18087->8080`)만 host port 공개. `identity-api`/`payment-api`/`db`/`db-checker`는 **host port 없음**(PORTS 칸 비어있거나 내부 5432만) |
| `curl -sI http://localhost:18086` | `HTTP/1.1 200 OK`, nginx — gateway 정적 페이지. body에 마커 `company-backend-boundary` |
| `curl -s http://localhost:18086/identity/users` | gateway가 `identity-api:3000`으로 routing → `{"service":"identity-api","users":[...seoul-maker(91), market-helper(84)]}` |
| `curl -s http://localhost:18086/payment/payments` | gateway가 `payment-api:3000`으로 routing → `{"service":"payment-api","payments":[pay-1001 approved, pay-1002 pending]}` |
| `curl -sI http://localhost:18087` | `HTTP/1.1 200 OK` — Adminer DB 관리 UI |
| `curl http://localhost:3000/users` (host 직접) | **응답 없음** — identity-api는 host에 3000을 안 열어서 gateway 통하지 않으면 접근 불가 |
| `docker compose logs db-checker` | `db:5432 - accepting connections` 후 `admin_checks` table 생성·insert·조회 성공 (service name `db`로 접속) |
| **`docker compose stop identity-api`** 후 `/identity/users` | **HTTP 502** (gateway가 죽은 upstream에 connect 실패) |
| 같은 상태에서 `/payment/payments` | **HTTP 200** 정상 — payment는 영향 없음 |
| 같은 상태에서 `/`(정적) | **HTTP 200** 정상 — gateway 자체는 살아있음 |
| `docker compose logs gateway` | `connect() failed (113: Host is unreachable) while connecting to upstream ... "GET /identity/users" ... 502` — upstream 실패가 gateway error log에 남음 |
| `docker compose down` | container 6개·network 3개 정리 (pgdata 보존) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 이 template은 무엇을 줄인 구조인가? | W1D4의 당근형 백엔드 경계 사례. 사용자/신뢰 정보는 `identity-api`, 결제 흐름은 `payment-api`로 **business 단위로 분리**하고, `gateway`가 외부 진입점을 하나로 모은다. DB 관리 UI(`adminer`)는 확인 도구로 붙인다. |
| 2교시(01-web-postgres)와 가장 큰 차이는? | 2교시는 API가 1개(catalog)였고, 여기는 **gateway 뒤에 API가 여러 개**다. 외부 진입점을 gateway 하나로 모으고 path(`/identity/`, `/payment/`)로 갈라 내부 API에 routing한다. service boundary가 처음으로 "여러 개"가 된다. |
| `identity-api`/`payment-api`에 `ports`가 없는 이유는? | 사용자는 **gateway로만** 들어와야 하기 때문. 내부 API는 host에 노출하지 않고 `app_net` 안에서 service name(`identity-api:3000`)으로만 호출된다. host에서 `localhost:3000`으로 직접 접근하면 응답이 없다(실증). |
| gateway는 어떻게 routing하나? | `nginx/default.conf`의 `location` 블록으로 path 매칭. `/identity/` → `proxy_pass http://identity-api:3000/`, `/payment/` → `payment-api:3000`, `/`는 정적 파일. upstream 주소가 IP가 아니라 **service name**이다. |
| Adminer에서 Server를 `localhost`로 넣으면? | 실패한다. Adminer **container 입장에서 `localhost`는 자기 자신**이지 DB가 아니다. DB는 같은 `data_net`의 service name `db`다. (Server=`db`, User/Pass=`postgres`, DB=`app`) |
| identity-api가 죽으면 어디까지 영향인가? | `/identity/`만 **502**가 되고, `/payment/`와 정적 페이지는 **200으로 정상**. gateway가 죽은 upstream에만 연결 실패하고 나머지 route는 멀쩡하다. **장애가 service 경계로 격리**된다 — 이게 boundary를 나눈 이유다. |
| `db-checker`는 2교시와 뭐가 다른가? | 2교시는 init.sql로 만든 products를 조회만 했는데, 여기 db-checker는 직접 `CREATE TABLE admin_checks` + `INSERT` + `SELECT`를 실행한다. init.sql 없이도 service name `db`로 붙어 쓰기까지 된다는 걸 logs로 보여준다. |

## notes

### gateway가 외부 진입점을 하나로 모은다 — 핵심 구조

2교시는 frontend→API 한 줄이었지만, 여기서는 **하나의 gateway 뒤에 여러 business API**가 숨는다. 이게 Week 3 MSA의 API gateway로 가는 다리다.

```text
browser → gateway(18086) ─┬─ /          → 정적 페이지 (gateway 자체)
                          ├─ /identity/ → identity-api:3000
                          └─ /payment/  → payment-api:3000
adminer(18087) ───────────────────────→ db:5432  (관리용 별도 경로)
```

| Service | 역할 | 공개 범위 | network |
|---|---|---|---|
| `gateway` | 정적 페이지 + path routing (nginx) | host `18086` | `public_net`, `app_net` |
| `identity-api` | 사용자/신뢰 정보 API (node) | **내부만** (`3000`) | `app_net` |
| `payment-api` | 결제 mock API (node) | **내부만** (`3000`) | `app_net` |
| `db` | PostgreSQL 16 | 내부 `5432`만 | `data_net` |
| `adminer` | DB 관리 UI | host `18087` | `public_net`, `data_net` |
| `db-checker` | DB 연결/쓰기 확인 보조 | logs만 | `data_net` |

network 배치가 "누가 누구에게 닿는가"를 강제한다:
- `gateway`는 `app_net`에 있어 API들과 만나지만 `data_net`엔 없어 **DB에 직접 못 붙는다**.
- `adminer`는 `data_net`에 있어 DB에 붙지만 `app_net`엔 없어 **API와는 무관**하다.
- API들은 `app_net`에만 있어 **DB에도 직접 못 붙는다**(이 lab에선 API가 DB를 안 씀).

### routing은 nginx `proxy_pass` + service name으로 한다

`gateway`의 nginx 설정이 path를 내부 API로 넘긴다.

```nginx
location /identity/ { proxy_pass http://identity-api:3000/; }
location /payment/  { proxy_pass http://payment-api:3000/; }
location /          { root /usr/share/nginx/html; }   # 정적
```

upstream 주소가 `http://identity-api:3000` — IP가 아니라 **service name**이다. 2교시에서 catalog-api가 `db:5432`로 DB를 찾던 것과 같은 원리(project network DNS)가, 여기선 gateway→API 방향에서 쓰인다.

> 끝의 `/`에 주의: `proxy_pass http://identity-api:3000/`는 `/identity/users` 요청에서 `/identity/`를 떼고 `/users`로 보낸다. 그래서 server.js의 `/users` 핸들러에 맞는다.

### gateway가 "하나"일 때의 함정 — SPOF와 수평 확장

gateway는 문 앞을 지키는 **보디가드**다 — 단일 진입점, routing, TLS 검문, 인증/인가, rate limit. 내부 API는 "이미 검문 통과한 요청만 온다"고 믿고 business logic에 집중한다(이 lab 구조).

| 보디가드 역할 | gateway가 하는 일 |
|---|---|
| 정문 하나로만 입장 | 단일 진입점 (옆문·뒷문 없음) |
| 층 안내 | routing (`/identity/`→identity-api) |
| 입구 검문 | TLS termination, 인증/인가 |
| 진상 차단 | rate limit, 수상한 요청 필터링 |

문제는 이 보디가드가 **한 명(gateway 1대)** 일 때다. 10만 트래픽을 혼자 받는 슈퍼맨이 아니다.

| 문제 | 내용 |
|---|---|
| 단일 장애점(SPOF) | gateway 1대 죽으면 뒤 API가 다 멀쩡해도 **아무도 못 들어옴** |
| 병목 | 그 한 대의 CPU/네트워크 한계 = 전체 서비스 한계 |

위에서 identity-api가 죽어도 payment는 살아있었지만(boundary 격리), **gateway가 죽으면 그 격리가 무의미하다** — 입구 자체가 닫히니까.

그래서 실무에선 보디가드를 **여러 명 + 앞에 안내원(LB)** 으로 둔다.

```text
              ┌─ gateway #1 ─┐
사용자 → LB ──┼─ gateway #2 ─┼─→ 내부 API들
(10만)        └─ gateway #3 ─┘
```

| 장치 | 역할 |
|---|---|
| gateway 복제(여러 대) | 트래픽 분담 + 한 대 죽어도 나머지가 받음 (HA) |
| 앞단 Load Balancer | 살아있는 gateway로 분배 (health check로 죽은 건 제외) |
| gateway는 stateless | 어느 대로 가도 동일 처리 → 복제·교체 자유 |
| auto scaling | 트래픽 늘면 gateway 수도 자동 증가 |

AWS에선 이 "확장되는 보디가드 + 안내원"을 직접 안 만들고 **관리형(ALB / API Gateway)** 으로 떠넘기는 게 보통이다(앞 TLS offload와 같은 맥락).

```text
보디가드 한 명이 10만 다 막는다 (X)  → 쓰러지면 전부 막힘 (SPOF)
여러 명 + 안내원(LB) (O)            → 나눠 받고, 하나 죽어도 버팀 + 필요하면 더 부름
```

핵심: gateway는 **논리적으로 단일 진입점이되, 물리적으론 여러 대**다. 버텨내는 힘은 한 대의 근성이 아니라 **여러 대 + LB + stateless + auto scaling**이라는 구조에서 나온다.

### 장애 영향 범위 — service boundary를 나눈 진짜 이유 (실증)

`identity-api`만 멈추고 확인한 결과:

| 요청 | identity-api 중지 후 | 의미 |
|---|---|---|
| `/identity/users` | **502** | 죽은 upstream에 gateway가 연결 실패 |
| `/payment/payments` | **200** | 다른 business 경계라 영향 없음 |
| `/`(정적) | **200** | gateway 자체는 살아있음 |

gateway error log에 `connect() failed (113: Host is unreachable) while connecting to upstream ... "GET /identity/users" ... 502`가 그대로 남는다. **장애가 service 경계 안에 갇힌다** — identity가 죽어도 결제는 받을 수 있다. business 단위로 service를 쪼개는 가장 큰 이유가 이 격리다.

한 덩어리(monolith)였다면 identity 코드의 장애가 결제까지 같이 끌고 내려갔을 것이다. (Week 3 MSA의 failure isolation / blast radius 개념의 출발점.)

### 502의 정체 — gateway는 살아있고 upstream이 죽은 것

502 Bad Gateway는 "**gateway는 멀쩡한데, 뒤에서 받아줄 upstream이 응답 안 함**"이다. 그래서 정적 페이지(`/`)와 `/payment/`는 200이 나온다.

| 코드 | 누가 문제인가 |
|---|---|
| 502 Bad Gateway | gateway는 정상, **upstream(API)이 죽었거나 연결 거부** |
| 504 Gateway Timeout | upstream이 살았지만 **응답이 느려 timeout** |
| 200인데 내용이 이상 | upstream은 응답함, 응답 **내용/로직** 문제 |

운영에서 502를 보면 gateway가 아니라 **그 route의 upstream API부터** 본다. (부하 노트의 "gateway log는 입구 증거, 원인은 내부 API에 있을 수 있다"와 같은 맥락.)

### service를 쪼개는 또 하나의 이유 — 자원 프로파일

business 경계(identity vs payment)뿐 아니라, **API마다 잡아먹는 자원이 다르다**는 것도 쪼개는 이유다.

| API 유형 | 많이 쓰는 자원 | 예시 |
|---|---|---|
| CPU-heavy | CPU | 이미지/영상 인코딩, 암호화, 추천/랭킹 계산, 압축 |
| Memory-heavy | RAM | 큰 캐시, in-memory 집계, 대용량 데이터 로딩 |
| I/O·File-heavy | 디스크/네트워크 | 파일 업로드/다운로드, 로그 수집, 백업, 스트리밍 |

이걸 **한 덩어리(monolith)** 에 다 넣으면, 한 기능 때문에 늘릴 때 안 늘려도 되는 것까지 통째로 복제된다.

```text
[monolith: CPU기능 + Memory기능 + File기능 한 덩어리]
이미지 인코딩(CPU) 폭증 → 서버를 3배로 scale out
  → 안 바쁜 Memory기능·File기능까지 3배 (CPU 1개 늘리려고 RAM·디스크도 3배 낭비)
```

| 한 덩어리의 문제 | 내용 |
|---|---|
| 비효율적 scale | CPU만 필요한데 memory·file 부분까지 같이 복제 → 자원 낭비 |
| 자원 경합 | File-heavy가 디스크 점유하면 CPU 계산도 느려짐. memory 누수 나면 전부 같이 죽음 |
| instance 타입 선택 불가 | CPU 최적/메모리 최적 인스턴스를 따로 못 고르고 "어중간한 하나"로 타협 |

resource profile별로 쪼개면 **독립적으로, 맞는 사양으로** scale 된다.

```text
encoding-api (CPU최적 인스턴스)   → 바쁠 때 이것만 3배
cache-api    (메모리최적 인스턴스) → 그대로 1개
upload-api   (디스크/대역폭 큰 것)  → 그대로 1개
```

| 이점 | 내용 |
|---|---|
| 독립 scale | 바쁜 service만 늘림, 나머지 안 건드림 |
| right-sizing | service별로 CPU최적/메모리최적/스토리지최적 인스턴스 선택 (AWS c/r/i 타입처럼) |
| 격리 | 한 service의 자원 폭주가 옆으로 안 번짐 (위 장애 격리와 같은 결) |

한 줄: **섞어 놓으면 한 자원만 모자라도 전부를 늘려야 하고, 한쪽이 폭주하면 다 같이 느려진다.** 그래서 business 경계뿐 아니라 자원 특성으로도 service를 쪼갠다. (2교시 connection pool 곱셈 함정도 "한 덩어리로 늘릴 때 드는 비용"의 한 사례.)

> 단, 무작정 쪼개면 service 수가 늘어 운영·네트워크 복잡도가 오른다. "정말 프로파일이 다르고 따로 scale 할 이유가 있을 때" 쪼개는 게 실무 균형점이다.

### Adminer — 편하지만 공개 범위를 의식해야 하는 도구

Adminer는 DB를 브라우저로 들여다보는 관리 UI다. 실습엔 편하지만 host `18087`로 **DB로 가는 문을 외부에 여는** 셈이다.

- 접속 시 Server에 `localhost`가 아니라 **service name `db`** — Adminer container의 localhost는 자기 자신이다(2교시 "service name으로 통신"과 동일).
- compose 주석도 "DB 확인 도구이므로 실습 후 노출을 정리해야 한다"고 명시.

#### 왜 웹 DB 관리 UI는 운영에서 위험한가

Adminer/phpMyAdmin/pgAdmin(web) 같은 건 **브라우저로 DB에 직접 들어가는 문**이라, host에 그냥 열면:

| 위험 | 내용 |
|---|---|
| 인증이 약함 | UI 로그인 = DB 계정. 털리면 곧 DB 전체 권한 |
| 공개 노출 | port만 열려 있으면 인터넷 스캔(Shodan 등)으로 발견됨 |
| 알려진 취약점 | phpMyAdmin/Adminer는 과거 RCE·SSRF CVE 이력이 있음 |
| 감사 부재 | 누가 무슨 쿼리를 날렸는지 추적이 약함 |

#### 그래서 실무에서는 — "안 쓴다"가 아니라 "public에 안 연다"

운영 DB 앞엔 보통 안 둔다. 두더라도 절대 public으로 안 열고 한 겹 가둔다.

| 보호 방법 | 내용 |
|---|---|
| 네트워크 격리 | VPN / bastion(점프 서버) / 사내망 안에서만 접근 |
| 포트 안 염 | host 노출 대신 `kubectl port-forward`·SSH tunnel로 그때만 임시 연결 |
| IP 화이트리스트 | security group / WAF로 특정 IP만 |
| 별도 인증 | UI 앞에 reverse proxy + SSO/basic auth 한 겹 더 |

더 흔한 대안: 클라이언트 도구(DBeaver, DataGrip, psql) + bastion 경유, 클라우드 콘솔(RDS Query Editor 등), 읽기는 읽기 전용 replica/BI 도구.

그래도 쓰는 곳은 있다 — 내부 스테이징/개발 DB, 작은 팀, 사내망 안 운영툴 등 **위험을 알고 격리해서** 쓰는 경우. 편의성 때문에 완전히 사라지진 않았다. 핵심은 **편하니까 격리된 환경에선 여전히 쓰되, public에는 절대 안 연다**는 것. 실습에선 끝나면 `down`으로 내린다.

### 트래픽/부하 성향 노트

모든 외부 요청이 gateway를 먼저 통과하지만, **실제 CPU 병목은 gateway보다 내부 API의 business logic**에서 나는 경우가 많다.

| Service | 트래픽 성향 | CPU 부하 | 메모리/상태 부하 | 먼저 볼 것 |
|---|---|---|---|---|
| `gateway` | 모든 route 진입 | routing/TLS/logging 많으면 증가 | connection buffer | route별 4xx/5xx, upstream error |
| `identity-api` | 로그인/사용자 조회 | token 검증, 권한 계산 | session/cache 연동 | auth 실패율, latency |
| `payment-api` | 결제/정산 | validation, 외부 PG 연동 | retry queue, idempotency store | 중복 요청, timeout |
| `db` | user/payment metadata | index 없는 조회, transaction | connection, buffer/cache | lock, slow query |
| `adminer` | 관리 traffic(운영 아님) | 낮음 | session | 수업 후 노출 정리 |

핵심은 "**gateway가 바쁘다**"와 "**business API가 무겁다**"를 분리해서 보는 것. gateway log는 입구 증거일 뿐, 원인은 identity/payment API나 DB에 있을 수 있다.

### Cleanup 기준

```bash
docker compose down       # container + network 정리 (pgdata 보존)
docker compose down -v    # named volume pgdata까지 삭제 — admin_checks 데이터 삭제
```

특히 `adminer`가 host에 열려 있으니 **실습이 끝나면 반드시 `down`**으로 DB 관리 UI를 내린다.

### 흔한 오해 / 실패

- 내부 API도 host port가 있어야 호출된다 → gateway가 service name으로 호출하므로 host port 불필요. 오히려 안 여는 게 보안상 맞다.
- Adminer Server에 `localhost` → 실패. container 자기 자신을 가리킴. service name `db` 사용.
- API 하나 죽으면 전체가 죽는다 → 502는 그 route만. 다른 경계(payment)와 gateway 자체는 정상. boundary가 장애를 격리한다.
- 502 = gateway 문제 → gateway는 살아있고 upstream이 죽은 것. 원인은 그 route의 API부터 본다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| `/identity/users`가 502 | identity-api upstream이 죽거나 연결 거부. gateway logs에서 `connect() failed ... upstream` 확인 → 해당 API container 상태(`docker compose ps`)부터 점검. payment/정적이 200이면 gateway는 정상 |
