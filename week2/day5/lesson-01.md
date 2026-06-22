# 1교시: Compose 기본 개념과 편의성

> 실습 검증은 강의자료 lab `week2/day5/labs/compose-architectures/01-web-postgres`(nginx + PostgREST + postgres 3-tier)로 진행했다.

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker compose -f .../01-web-postgres/compose.yaml config` | 실행 전 정규화 출력. `depends_on`이 `condition: service_started`로 확장, bind volume source가 절대경로로, `ports`가 `target/published/protocol` 구조로 풀려서 표시됨 |
| `docker compose config --services` | service 4개(`db`, `db-checker`, `catalog-api`, `frontend`) 확인 |
| `docker compose up -d` | network(`public/app/data_net`)·volume(`pgdata`)·container 생성 후 `depends_on` 순서대로 기동(`db` → `catalog-api`/`db-checker` → `frontend`) |
| (관찰) `frontend` 기동 실패 | `Bind for 0.0.0.0:18085 failed: port is already allocated` — 다른 컨테이너(day4 observability lab)가 18085 점유 중. 나머지 service는 정상 기동 |
| `docker compose ps` | `catalog-api`(`18101->3000`), `db`(내부 `5432`), `db-checker` 모두 `Up` 확인 |
| `docker logs ...-db-checker-1` | `pg_isready`로 DB 대기 후 `SELECT ... FROM api.products`로 상품 3행 조회 성공 (service name `db`로 접속) |
| `curl -s http://localhost:18101/products` | PostgREST(`catalog-api`)가 `PGRST_DB_URI=...@db:5432/...`로 DB에 붙어 JSON 3건 반환 |
| `docker compose down -v` | container·network 정리 + named volume `pgdata`까지 삭제(실습이라 데이터 삭제 허용) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 왜 `docker run` 대신 Compose를 쓰는가? | 긴 `docker run`은 순서가 중요하고 사람이 빠뜨리기 쉬워 인수인계·재현성이 깨진다. `compose.yaml`은 실행 조건(image, port, env, volume, network, 순서)을 파일로 남긴 **local architecture template**이라 팀원이 같은 환경을 재현할 수 있다. |
| container끼리는 어떻게 통신하는가? | `localhost`가 아니라 **service name**으로 만난다. 이 lab에서 `catalog-api`는 `PGRST_DB_URI`의 host를 `db`로 두고 `db:5432`에 접속한다. Compose가 만든 project network 안에서 service name이 DNS로 동작한다. |
| `docker compose config`를 먼저 보는 이유는? | 실행 전에 Compose 파일을 정규화해 보여준다. 어떤 image로 뜨는지, 어떤 port를 host에 공개하는지, 어떤 volume을 붙이는지 미리 독해할 수 있다. `depends_on`→`condition`, 상대경로→절대경로처럼 실제 적용될 값으로 풀려 나온다. |
| `depends_on`은 무엇을 보장하는가? | 시작 **순서 힌트**일 뿐이다. `condition: service_started`는 컨테이너가 시작됐다는 것이지, DB가 쿼리를 받을 준비가 됐다는 뜻이 아니다. 그래서 `db-checker`가 `pg_isready`로 따로 ready를 기다린 뒤에 쿼리한다. |
| `frontend`만 실패하고 나머지는 왜 정상인가? | Compose는 service를 만들다 한 컨테이너가 port 충돌(`18085 already allocated`)을 만나면 그 컨테이너만 실패하고 이미 뜬 service는 그대로 둔다. port 충돌은 가장 흔한 Compose 실패 중 하나다. |
| `down`과 `down -v`의 차이는? | `down`은 container와 network를 정리한다. `down -v`는 named volume(`pgdata` = DB 데이터)까지 지운다. DB가 있는 stack에서 `down -v`는 실습 데이터 삭제다. |

## notes

### 왜 Compose인가 — `docker run`을 파일로 남긴다

Day 3~4의 `docker run`은 길고, 순서가 중요하고, 빠뜨리기 쉽다. Compose는 그 실행 조건을 파일 하나로 남긴 **local architecture template**이다.

| `docker run`에서 하던 일 | Compose에서 읽는 위치 |
|---|---|
| image 선택 | `services.<name>.image` 또는 `build` |
| host port 공개 | `ports` |
| runtime config | `environment`, `env_file` |
| data 보존 | `volumes` |
| service 간 통신 | service name + project network |
| 실행 순서 힌트 | `depends_on` |

### 공통 검증 루프

모든 Compose 템플릿은 같은 순서로 확인한다.

```bash
docker compose config        # 실행 전 정규화해서 독해
docker compose up -d         # 백그라운드 기동
docker compose ps            # service 상태 확인
docker compose logs --tail 80
```

`config`를 먼저 보는 것이 핵심이다. 실제로 돌려보니 `depends_on`이 `condition: service_started`로, `./db/init.sql` 상대경로가 절대경로로, `ports`가 `{target, published, protocol}` 구조로 정규화돼 나왔다. **파일에 적은 것과 실제 적용되는 값이 같은지** 실행 전에 확인할 수 있다.

### compose.yaml은 암기가 아니라 독해 대상이다

YAML 줄을 외우지 말고 다음 질문으로 읽는다.

| 읽는 곳 | 답하는 질문 |
|---|---|
| `ports` | 외부에서 들어오는 traffic의 진입점은 어디인가 |
| `environment` + service name | service끼리 어떤 이름으로 만나는가 |
| `volumes` | 상태를 가진 service의 data lifecycle은 어떻게 되는가 |
| `depends_on` | 시작 순서 힌트는 무엇인가 |

### service name으로 통신한다 (실증)

container끼리는 `localhost`가 아니라 service name으로 만난다. 이 lab에서 검증됐다.

- `catalog-api`(PostgREST)는 `PGRST_DB_URI: postgres://...@db:5432/app` — host가 `db`(service name).
- `db-checker`는 `psql ...@db:5432/app`로 접속해 상품 3행을 조회.
- 둘 다 IP가 아니라 **service name `db`**로 DB를 찾았다. Compose가 만든 project network 안에서 service name이 DNS로 동작하기 때문이다.

### Compose가 이름을 짓는 규칙 — 프로젝트 prefix

`compose.yaml`엔 짧은 이름(`web`, `db`, `pgdata`, `data_net`)만 적는데, 실제 생성될 땐 앞에 **프로젝트 이름**이 붙는다. `docker compose down` 출력에서 `day5-db-1`, `day5_data_net`, `day5_pgdata`처럼 보이는 이유다.

| compose.yaml | 실제 생성된 이름 | 규칙 |
|---|---|---|
| `services: web` | `day5-web-1` | `<프로젝트>-<서비스>-<번호>` |
| `services: db` | `day5-db-1` | 〃 |
| `networks: data_net` | `day5_data_net` | `<프로젝트>_<네트워크>` |
| `volumes: pgdata` | `day5_pgdata` | `<프로젝트>_<볼륨>` |

각 조각의 출처:
- **`day5`** = 프로젝트 이름. 기본값은 **compose.yaml이 있는 폴더 이름**이다.
- **`web`/`db`** = `services:` 아래 키 이름.
- **`-1`** = 같은 서비스의 몇 번째 컨테이너인지(replica 번호). 1개면 항상 `-1`.

> 컨테이너는 `-`(하이픈), 네트워크·볼륨은 `_`(언더스코어)로 붙는다 — Compose 버전 관례 차이다.

프로젝트 이름을 폴더명 말고 직접 지정하려면:

| 방법 | 예 |
|---|---|
| `-p` 플래그 | `docker compose -p myproj up -d` → `myproj-web-1` |
| 환경변수 | `COMPOSE_PROJECT_NAME=myproj` |
| compose.yaml 최상단 | `name: myproj` |

**왜 prefix를 붙이나:** 이름 충돌 방지다. 다른 프로젝트에도 `web`/`db` 서비스가 있을 수 있으니, 프로젝트별로 묶어두면 섞이지 않고 `docker compose down`도 "이 프로젝트 것만" 골라 지운다. 짧은 service name(`db`)은 같은 compose 안의 **내부 통신용 DNS 이름**이고, `day5-db-1`은 Docker 전체에서의 **실제 컨테이너 이름**이다 — 위 "service name으로 통신한다"와 연결된다.

### depends_on은 순서 힌트지 readiness 보장이 아니다

`depends_on`은 "먼저 시작하라"는 순서 힌트일 뿐, "준비가 됐다"는 보장이 아니다. `condition: service_started`는 컨테이너 시작만 의미한다. 그래서 lab의 `db-checker`는 `until pg_isready ...; do sleep 1; done`으로 DB가 연결을 받을 때까지 기다린 뒤에 쿼리한다.

```text
depends_on   → "db를 먼저 시작하라" (순서)
pg_isready   → "db가 연결을 받을 준비가 됐는지" (readiness)
```

운영에서 readiness까지 보장하려면 healthcheck + `condition: service_healthy`나 애플리케이션 재시도 로직을 쓴다.

### 네트워크는 보안 장벽이 아니라 구조화 도구

Compose network는 로컬 실습에서 service가 어느 영역에 속하는지 보여주는 **구조화 도구**다. lab은 `public_net`(외부 traffic), `app_net`(service 간), `data_net`(DB 영역)으로 나눠 `db`를 `data_net`에만 둔다. 다만 이것을 "보안 장벽"으로 과장하지 않는다. 운영 통제는 firewall, security group, Kubernetes NetworkPolicy, IAM과 함께 생각해야 한다.

### service 유형별 확인 방법

| 서비스 유형 | 확인 예시 |
|---|---|
| Web | `curl -I http://localhost:<port>` |
| API | `curl -s http://localhost:<port>/<resource>` |
| DB | `docker compose exec db psql ...` |
| Cache | `docker compose exec redis redis-cli GET ...` |
| Queue/Worker | `docker compose logs worker --tail 40` |
| Proxy | proxy port로 접속하고 upstream service port는 직접 열지 않는다 |

### Cleanup 기준

```bash
docker compose down       # container + network 정리 (data 보존)
docker compose down -v    # named volume까지 삭제 — DB/cache 데이터 삭제
```

`down -v`는 DB가 있는 템플릿에서 **실습 데이터 삭제**다. 데이터를 지워도 되는 실습에서만 쓴다. (day4 1교시 prune 정리와 같은 원칙: named volume 삭제는 의도적으로만.)

### 설정을 바꿨는데 안 먹을 때 — stale 상태와 recreate

"설정을 고쳤는데 반영이 안 된다"의 원인은 거의 항상 **기존에 만들어진 무언가가 옛 상태(stale)를 그대로 들고 있기** 때문이다. 해결은 둘 중 하나 — 버리고 새로 만들거나(recreate), 명시적으로 갈아끼우거나.

| stale의 정체 | 왜 안 먹나 |
|---|---|
| 기존 container | 생성 시점 설정으로 떠 있음. env file을 고쳐도 그 container에는 반영 안 됨 (day4 1교시) |
| 기존 volume의 데이터 | 초기화가 "처음 한 번만" 도는 경우, 옛 데이터가 남아 새 설정을 덮음 |
| build/image 캐시 | 옛 layer를 재사용해 새 변경이 빌드에 안 들어감 |

특히 좋은 예가 이 lab의 `db/init.sql`이다. `/docker-entrypoint-initdb.d/`의 스크립트는 **데이터 디렉토리(pgdata volume)가 비어 있을 때만 최초 1회** 실행된다. 그래서 `init.sql`을 고치고 `up` 해도 pgdata가 이미 있으면 안 먹는다. `down -v`로 volume을 비워야 새 init이 적용된다.

```text
init.sql 수정 → docker compose up → 안 먹음 (pgdata가 이미 있어 init 안 돎)
docker compose down -v → up        → 새 init.sql 적용
```

해결 사다리 (가벼운 것 → 무거운 것):

```bash
docker compose up -d                  # 바뀐 service만 자동 recreate (보통 이걸로 됨)
docker compose up -d --force-recreate # 변화 감지를 못 해도 강제로 다시 만듦
docker compose up -d --build          # 이미지/빌드 변경까지 반영
docker compose down && up -d          # container/network를 완전히 새로
docker compose down -v && up -d       # volume(데이터)까지 버리고 완전 초기화 (가장 강력/위험)
```

### 운영에서의 같은 원리 — maintenance window

stale 상태를 안 끊고 새 설정을 얹으면 꼬인다. 운영에서는 **순서를 정해 안전하게 교체**하는데, 이것이 maintenance window(점검 창)다. (예: 게임 점검 — 로그인 차단 → 강제 킥 → 점검 → 다시 오픈)

| 점검 단계 | 일반화한 개념 | Docker/K8s 대응 |
|---|---|---|
| 로그인 차단 | 신규 트래픽 차단 | LB에서 빼기, maintenance mode, feature flag off |
| 강제 킥(세션 끊기) | 기존 연결 drain/정리 | graceful shutdown, connection draining, 기존 container 종료 |
| 점검(설정 교체) | stale 상태 교체 | `down` → 새 설정으로 `up`, 이미지 교체 |
| 다시 로그인 열기 | 트래픽 복귀 | LB에 다시 넣기, flag on |

핵심: **기존 세션이 옛 상태를 쥔 채로 있으면 새 설정과 꼬인다.** 그래서 먼저 끊고(킥) → 막고(차단) → 갈고 → 검증 후 연다. `--force-recreate`로 container를 끊고 새로 만드는 것과 발상이 같다. 무중단으로 하려면 한 번에 끊는 대신 조금씩 교체하는 rolling update나 blue-green을 쓴다.

이는 day4 3교시의 snowflake vs phoenix와 이어진다. 손으로 달래서 고친 서버는 stale이 쌓여 재현이 안 된다. 설정이 안 먹으면 **버리고 코드(Dockerfile/compose/init)에서 다시 만드는 게** 정답이다 — cattle, not pets.

### 끊김의 책임은 "그때 무슨 트랜잭션이었나"에 달려 있다

ALB(또는 LB) 뒤에 컨테이너 a/b/c가 있을 때, 그중 하나가 죽으면 그 컨테이너가 처리 중이던 in-flight 요청이 날아간다. 끊김 자체가 문제가 아니라 **끊긴 그 순간 무슨 트랜잭션이 진행 중이었느냐**가 회사 책임의 크기를 결정한다. 그래서 같은 "컨테이너 1개 죽음"인데 영향이 극과극이다.

| 끊긴 요청 | 끊기면 생기는 일 | 회사 책임 |
|---|---|---|
| 조회 (랭킹, 친구 목록) | 새로고침하면 끝 | 거의 없음 |
| 멱등한 쓰기 (설정 변경) | 다시 누르면 됨 | 작음 |
| **결제 / 재화 지급 (유료 상품·현질)** | 돈은 빠졌는데 아이템 안 들어감 / 중복 결제 / 아이템만 주고 결제 롤백 | **금전 손해 + 환불·보상 + CS 폭주 + 법적·평판 리스크** |

게임 회사 유료 상품이 맨 아래 칸이다. 유저가 결제하는 찰나에 컨테이너가 죽으면 "돈 냈는데 아이템 없음"이 되어, 조회가 끊긴 것과는 책임이 비교가 안 된다. 그래서 "컨테이너는 언제든 죽여도 되는 cattle"이라는 말이 **돈을 다루는 시스템에서도 성립하려면** 두 겹의 방어가 필요하다.

#### ① 끊는 방식 — graceful하게 (위의 maintenance window와 같은 원리)

컨테이너를 그냥 `kill`하지 않고 ALB 앞에서 순서를 지킨다.

```text
1. ALB가 그 컨테이너로 새 요청을 그만 보냄   (target에서 deregister)
2. 이미 처리 중인 요청은 끝까지 완료시킴       (connection draining, 보통 수십~300초)
3. 다 빠진 뒤에 컨테이너 종료                (graceful shutdown: SIGTERM 후 유예)
```

이것이 ALB의 **deregistration delay(connection draining)** 이고, 게임 점검 때 "로그인 막고 → 세션 정리 → 점검"하는 것과 똑같은 발상이다. **진행 중인 결제를 중간에 끊지 않으려고** 미리 트래픽을 빼는 것이다.

#### ② 그래도 끊겼을 때 — 트랜잭션 자체가 안전해야

draining을 해도 장애로 갑자기 죽을 수 있다. 그때 돈 사고가 안 나려면:

| 안전장치 | 막는 것 |
|---|---|
| **원자성** (DB transaction commit/rollback) | 중간에 죽어도 commit 전이면 통째 롤백 → "돈만 빠지고 아이템 안 줌" 방지 |
| **멱등성** (idempotency key) | 재시도해도 결제·지급이 한 번만 일어남 → 중복 결제/중복 지급 방지 |
| **정산/대사** (reconciliation) | 외부 PG와 내부 DB를 주기적으로 맞춰 불일치(돈은 들어왔는데 미지급) 적발·보정 |

특히 위험한 건 결제가 **외부 PG(결제대행) + 내부 DB 두 곳에 걸쳐** 있을 때다. 그 사이에 컨테이너가 죽으면 "PG엔 결제됨 / 우리 DB엔 미반영" 불일치가 남는다. 그래서 outbox/saga 패턴, idempotency key, 사후 reconciliation으로 메꾼다.

정리: phoenix server(언제든 죽여도 됨)가 돈 다루는 시스템에서 성립하려면 ⓐ 상태를 컨테이너 밖(DB)에 두고(stateless), ⓑ 진행 중 작업을 graceful하게 마무리하고, ⓒ 트랜잭션이 원자적·멱등적이어야 한다. 이 셋이 받쳐줄 때만 "컨테이너 하나쯤 죽어도 된다"가 된다. 안 받쳐주면 컨테이너 교체(배포·점검)가 곧 금전사고다.

### 흔한 오해 / 실패

- Compose는 단순한 편의 문법이다 → 실행 조건을 남긴 architecture template이다. 독해 대상.
- `depends_on`이면 DB가 준비된 뒤 app이 뜬다 → 시작 순서일 뿐. readiness는 healthcheck/재시도로.
- container끼리 `localhost`로 통신한다 → service name으로 만난다. `localhost`는 컨테이너 자기 자신.
- `up`이 전부 성공해야만 한다 → 한 service가 port 충돌로 실패해도 나머지는 뜬다. `ps`/`logs`로 어느 service가 실패했는지 확인한다. (이번 실습의 `frontend` 18085 충돌 사례)

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
