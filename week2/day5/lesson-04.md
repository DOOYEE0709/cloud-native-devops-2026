# 4교시: 토스형 프론트엔드 플랫폼 template

> 실습 검증은 lab `week2/day5/labs/compose-architectures/03-web-redis`(nginx web + config-api(node) + redis cache + cache-writer + redis-cli(profile tool))로 진행했다.

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker compose config --services` | service 4개 — `redis`, `cache-writer`, `config-api`, `web`. **`redis-cli`는 안 보임**(profile `tool`이라 기본 제외) |
| `docker compose --profile tool config --services` | `redis-cli` 추가돼 5개 — profile을 켜야 등장 |
| `docker compose up -d` | network 3개(`public_net`/`app_net`/`cache_net`) 생성, container 4개 기동. `redis-cli`는 자동 기동 안 됨 |
| `docker compose ps` | `web`(`0.0.0.0:18088->80`), `config-api`(`0.0.0.0:18103->3000`)만 host 공개. `redis`/`cache-writer`는 내부 `6379`만 |
| `curl -sI http://localhost:18088` | `HTTP/1.1 200 OK`, nginx. body 마커 `company-frontend-platform` |
| `curl -s http://localhost:18103/config` | `{"service":"config-api","apiBaseUrl":"http://localhost:18101","featureFlags":{"newCheckout":true,"aiReview":false}}` — env 값이 그대로 JSON으로 |
| `docker compose logs cache-writer` | `OK` / `hit-from-cache-writer` 가 5초마다 반복 — `redis-cli -h redis`로 SET/GET 루프 |
| `docker compose exec redis redis-cli GET compose:cache` | `hit-from-cache-writer` — service name `redis`로 접근해 cache-writer가 쓴 값 조회 |
| `docker compose --profile tool run --rm redis-cli` | `PONG` — profile 도구로 일회성 `redis-cli PING` 실행 후 자동 삭제(`--rm`) |
| (시도) `FEATURE_AI_REVIEW=true docker compose up -d config-api` | **반영 안 됨** — compose에 `"false"`로 **하드코딩**돼 있어 shell 환경변수가 override 못 함(`${VAR}` 아님) |
| `docker compose config \| grep redis -A3` | redis에 **`volumes` 없음** — cache는 휘발성 |
| redis에 `my:temp` SET → `docker compose rm -sf redis` → `up` | 새 컨테이너에서 `GET my:temp` = **(nil)**. volume이 없어 컨테이너 제거 시 cache 소멸 |
| 같은 상황에서 `GET compose:cache` | `hit-from-cache-writer` **재등장** — cache-writer가 5초마다 다시 써서 |
| `docker compose --profile tool down` | container·network 정리 (volume 자체가 없음) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 이 template은 무엇을 줄인 구조인가? | W1D4 프론트엔드 플랫폼 사례. 화면은 `web`(nginx)이 주고, **설정은 `config-api`가 runtime에 제공**하고, `redis`는 **외부 backing service로 붙은 cache**다. "설정과 cache를 app 밖으로 빼낸" 구조. |
| feature flag를 왜 env로 두나? | `config-api`는 `process.env.FEATURE_NEW_CHECKOUT === "true"`로 flag를 읽는다. flag가 **image에 구워진 게 아니라 runtime 환경변수**라, image 재빌드 없이 env만 바꿔 재기동하면 동작이 바뀐다. `/config` 응답의 `newCheckout:true, aiReview:false`가 env 값 그대로다. |
| 그런데 왜 env override가 안 먹었나? | 이 lab은 compose에 `FEATURE_AI_REVIEW: "false"`로 **값을 직접 적어** 둬서, shell의 `FEATURE_AI_REVIEW=true`가 끼어들 자리가 없다. override하려면 compose에서 `${FEATURE_AI_REVIEW}`처럼 **interpolation 형태**로 써야 한다. (config로 실제 적용값을 미리 확인하는 게 중요한 이유.) |
| cache는 app 안의 변수랑 뭐가 다른가? | cache는 app process 내부 변수/파일이 아니라 **별도 service(redis)**다. 그래서 **app(web/config-api)이 재시작돼도 redis가 살아있으면 cache는 유지**되고, 반대로 **redis 컨테이너가 사라지면 cache도 사라진다**(실증: `rm` 후 `my:temp`=nil). |
| cache lifecycle과 DB lifecycle의 차이는? | 2교시 `db`는 named volume `pgdata`가 있어 `down`해도 데이터가 남고 `down -v`로만 지워졌다. 여기 `redis`는 **volume이 아예 없어** 컨테이너 제거만으로 데이터가 날아간다. cache는 "사라져도 되는 데이터"라 보통 영속화 안 한다(필요하면 다시 채워짐). |
| `redis-cli` service는 왜 `ps`에 안 떴나? | `profiles: ["tool"]`이 붙어 **평소엔 기동/표시 안 되는 선택적 도구**다. `--profile tool`을 줘야 config/run에 등장한다. 늘 띄울 필요 없는 점검용 도구를 분리하는 패턴. |

## notes

### 핵심 구조 — 설정과 cache를 app 밖으로 뺀다

2~3교시가 "API/DB/gateway"였다면, 4교시 키워드는 **runtime config**와 **backing service(cache)**다.

```text
browser → web(18088, 정적 화면)
        → config-api(18103) ── /config ── runtime 설정 + feature flag (env에서 읽음)
                  └──────────────────────→ redis (cache, service name으로 접근)
cache-writer ─(5초마다 SET/GET)─→ redis
```

| Service | 역할 | 공개 범위 | network |
|---|---|---|---|
| `web` | preview 화면 (nginx 정적) | host `18088` | `public_net`, `app_net` |
| `config-api` | runtime config + feature flag API (node) | host `18103` | `public_net`, `app_net`, `cache_net` |
| `redis` | cache (backing service) | 내부 `6379`만 | `cache_net` |
| `cache-writer` | redis에 주기적으로 쓰는 sample | logs만 | `cache_net` |
| `redis-cli` | 수동 점검 도구 (선택적) | `--profile tool`일 때만 | `cache_net` |

### feature flag는 image가 아니라 runtime config에 둔다

핵심 원칙: **설정을 image 안에 굽지 않는다.** `config-api`의 image는 평범한 `node:20-alpine`이고, 동작을 가르는 flag는 전부 `environment:`에 있다.

```js
// server.js — flag를 runtime env에서 읽는다
newCheckout: process.env.FEATURE_NEW_CHECKOUT === "true",
aiReview:    process.env.FEATURE_AI_REVIEW === "true"
```

이러면 같은 image로 환경마다 다른 동작을 낼 수 있다(dev는 실험 flag on, prod는 off). 이 발상이 나중에 **Kubernetes ConfigMap/Secret, Terraform variable, 환경별 `.env` 분리**로 이어진다.

> 실증의 반전: env override(`FEATURE_AI_REVIEW=true docker compose up`)가 **안 먹었다**. 이 lab은 compose에 `"false"`를 **하드코딩**했기 때문이다. flag를 진짜 바깥에서 주입하려면 compose에 `FEATURE_AI_REVIEW: ${FEATURE_AI_REVIEW:-false}`처럼 **interpolation**으로 적어야 한다. "원칙(env로 분리)"과 "구현 디테일(interpolation으로 열어둬야 override됨)"은 다른 얘기다.

### cache는 별도 service다 — data lifecycle이 DB와 다르다 (실증)

cache는 app container 안의 변수가 아니라 **독립 service(redis)**다. 그래서 수명이 app과 분리된다.

| 상황 | cache(redis) | 이 lab 결과 |
|---|---|---|
| app(web/config-api) 재시작 | redis 살아있으면 **유지** | cache 그대로 |
| redis 컨테이너 제거(`rm`)/재생성 | volume 없으면 **소멸** | `my:temp` → (nil) |
| cache-writer가 다시 씀 | 소멸돼도 **다시 채워짐** | `compose:cache` 재등장 |

2교시 DB와 대비하면 차이가 분명하다:

```text
db   : named volume pgdata 있음 → down으로 안 지워짐, down -v로만 삭제 (영속 데이터)
redis: volume 없음            → 컨테이너 제거만으로 사라짐 (휘발 cache)
```

**의도된 설계다.** cache는 "사라져도 원본(DB 등)에서 다시 채울 수 있는 데이터"라 굳이 영속화 안 한다. 반대로 DB 원본 데이터는 사라지면 끝이라 volume으로 지킨다. "이 데이터는 잃어도 되는가?"가 volume을 붙일지 가르는 기준이다.

> 단, redis도 RDB/AOF로 영속화할 수 있고 volume을 붙이면 보존된다. 이 lab은 "cache는 휘발"을 보여주려고 일부러 volume을 안 붙인 것.

### Redis는 빠르지만 무한하지 않다 — memory pressure / eviction

cache는 메모리에 올라가므로 빠르지만 **용량이 유한**하다. key가 계속 늘면:

- memory가 차고 → eviction policy에 따라 오래된 key를 버리거나(LRU 등) 쓰기를 거부한다.
- 이때 "있을 줄 알았던 cache가 없어"져서 DB로 요청이 몰리고(cache miss 폭증), app latency가 갑자기 흔들린다.

운영에서 redis는 **memory usage, key count, eviction 수, hit/miss 비율**을 본다. (2교시 connection pool처럼 "유한한 자원"이라는 같은 결.)

### Redis 논리 DB(0~15) — 번호지 이름이 아니다

Redis 한 인스턴스 안에는 **번호로 구분되는 논리 DB가 기본 16개(0~15)** 있다. 이걸로 용도를 나눠 쓰거나(예: 0=session, 1=cache, 2=queue) 그냥 0번 하나만 쓴다.

실증:

```text
CONFIG GET databases → 16            # 기본 16개
redis-cli -n 15 PING → PONG          # 0~15까지 유효
redis-cli -n 16 PING → ERR DB index is out of range  # 16은 범위 밖
```

**핵심 ①: 이름이 아니라 번호다.** PostgreSQL은 `app` 같은 **이름 있는 database**를 만들어 `-d app`으로 붙었다(2교시). Redis 논리 DB는 이름이 없고 **번호(0~15)** 뿐이다. `SELECT <n>` 또는 `redis-cli -n <n>`, 접속 URL `redis://host:6379/1`로 고른다.

```text
redis-cli -n 0 SET k "in-db-0"
redis-cli -n 1 GET k → (nil)        # db1엔 없음
redis-cli -n 0 GET k → in-db-0      # db0에만 있음
```

**핵심 ②: 메모리는 나뉘지 않는다.** 논리 DB 0~15는 **같은 인스턴스의 메모리를 공유**한다. db별로 maxmemory가 따로 있는 게 아니라, 16개를 합친 총량이 그 인스턴스 한도에 걸린다. 그래서 "DB를 나눴으니 자원도 격리됐다"는 오해다 — **논리적 분리일 뿐 자원 격리가 아니다**. (진짜 격리하려면 인스턴스를 따로 띄운다.)

> 그래서 요즘은 논리 DB로 나누기보다 **key prefix**(`session:`, `cache:`)로 구분하는 걸 더 권한다. Redis Cluster에선 논리 DB(번호 선택)를 아예 안 쓴다(0번만).

**핵심 ③: 그래서 메모리 관리가 redis의 핵심이다.** 이 lab은 아키텍처상 **redis가 단 하나**라 모든 cache가 그 한 인스턴스 메모리에 올라간다. 논리 DB를 나눠도 메모리는 공유라, **이 redis의 메모리가 곧 전체 cache 용량**이다. key가 무한정 늘면 위 "memory pressure / eviction"이 바로 이 하나에서 터진다. redis에서 메모리를 가장 신경 써야 하는 이유다.

### Redis 보안 — 격리 + auth + ACL

이 lab의 redis는 **비밀번호가 없다.** 그래도 그나마 안전한 이유는 비번이 아니라 **네트워크 격리** 때문이다.

| 보호 | 이 lab |
|---|---|
| 네트워크 격리 | `redis`는 `cache_net`에만, **host에 6379 안 염** → 외부에서 직접 못 붙음 |
| 비밀번호(auth) | **없음** (그래서 cache-writer가 `redis-cli -h redis SET ...`을 비번 없이 바로 함) |

즉 **1차 방어는 격리**다. redis를 host로 열거나 인터넷에 노출하면 비번이 필수다(비번 없는 redis가 노출됐다가 통째로 털리는 사고가 흔하다).

**① 비밀번호(auth) — `requirepass`.** compose에서:

```yaml
redis:
  image: redis:7-alpine
  command: ["redis-server", "--requirepass", "${REDIS_PASSWORD}"]
  networks: [cache_net]

cache-writer:
  command:
    - sh
    - -c
    - redis-cli -h redis -a "${REDIS_PASSWORD}" SET compose:cache "v"
```

비번은 4교시 원칙대로 **env로 주입**하고 image에 안 굽는다. 동작:

```text
redis-cli PING           → NOAUTH Authentication required.   (인증 안 하면 거부)
redis-cli -a s3cret PING → PONG                              (비번 주면 통과)
```

**② ACL(Redis 6+) — 사용자별 키/명령 권한.** `requirepass`는 `default` 사용자에게 비번을 거는 것이고, ACL은 "누가 어떤 키에 무슨 명령을" 까지 통제한다(최소 권한).

```bash
# alice는 cache:* 키에 get/set만 허용
redis-cli -a s3cret ACL SETUSER alice on ">alicePass" "~cache:*" "+get" "+set"
```

동작:

```text
redis-cli --user alice -a alicePass SET cache:x ok → OK   (허용된 키)
redis-cli --user alice -a alicePass GET other:y       → NOPERM (권한 밖 키는 거부)
```

**서버 접속 정리** (비번/ACL 건 redis에 붙는 법):

| 상황 | 명령 |
|---|---|
| 비번만 (default user) | `redis-cli -h redis -a "$REDIS_PASSWORD"` |
| 접속 후 인증 | 붙은 다음 `AUTH <password>` |
| ACL 사용자 | `redis-cli -h redis --user alice -a alicePass` |
| 비번 노출 경고 회피 | `-a` 대신 환경변수 `REDISCLI_AUTH=...` 사용 |

> `-a`를 커맨드라인에 쓰면 `Warning: Using a password ... may not be safe` 경고가 뜬다(쉘 히스토리/프로세스 목록 노출). 스크립트에선 `REDISCLI_AUTH` env로 넘기는 게 안전하다.

정리: **격리(1차) + auth(2차) + ACL(최소 권한, 3차)** 를 겹쳐 쓴다. 이 lab은 격리만으로 충분해 비번을 생략했지만, 노출이 필요한 운영에선 셋을 같이 건다. (3교시 Adminer "public에 안 연다"와 같은 다층 방어.)

### 로컬 host 포트 vs AWS VPC 격리 — 같은 redis인데 접근이 다른 이유

로컬에서 redis에 GUI로 붙으려면 `ports: "16379:6379"`를 열면 된다. 그런데 이게 **되는 이유는 redis 컨테이너가 내 노트북 위에서 돌기 때문**이다. host = 내 기계라 포트를 매핑하면 `127.0.0.1`로 바로 닿는다.

```text
[내 노트북]  GUI(127.0.0.1:16379) → docker가 연 host 포트 → redis 컨테이너  ✅ (같은 기계)
```

AWS에선 이 방식이 안 통한다. Redis는 보통 **ElastiCache(관리형)** 로 **VPC(사설망) 안 private subnet**에 있다.

```text
[AWS VPC]  앱 컨테이너 → ElastiCache:6379   ✅ (같은 VPC)
[내 노트북] ──X──→ ElastiCache              ❌ (VPC 밖, 닿는 길 없음)
```

| | 로컬 docker | AWS |
|---|---|---|
| redis 위치 | 내 노트북 | VPC 안 private subnet |
| 내 기계가 같은 네트워크? | 예(같은 기계) | 아니오(VPC 밖) |
| 접근 통제 | host 포트 매핑 | security group + subnet (기본 public 차단) |
| GUI 직접 연결 | 됨 | 안 됨(터널 없이는) |

즉 AWS에선 "포트를 설정하고 말고"가 아니라 **redis가 사설망에 갇혀 있고 내 노트북은 그 밖**이라 직접 못 닿는다. ElastiCache는 **public으로 안 여는 게 정석**(인터넷에 redis 노출 = 사고)이다. 보려면 lesson-03 Adminer와 똑같이 통로를 뚫는다:

| 방법 | 내용 |
|---|---|
| Bastion 경유 | VPC 안 서버에 SSH로 들어가 거기서 `redis-cli` |
| SSH 터널 | `ssh -L 16379:<엔드포인트>:6379 bastion` 후 로컬 GUI를 `127.0.0.1:16379`로 |
| VPN | 노트북을 VPC 망에 합류 |
| (EKS) `kubectl port-forward` | pod 포트를 로컬로 임시 포워딩 |

한 줄: **로컬은 redis가 같은 기계 위라 host 포트로 바로 되고(그래서 실습이 됨), AWS는 VPC에 가둬서 직접 못 닿는다.** 격리 원칙이 로컬은 Compose network, AWS는 VPC+security group으로 더 강하게 구현된 것.

### 트래픽/부하 성향 노트

| Service | 트래픽 성향 | CPU 부하 | 메모리/상태 부하 | 먼저 볼 것 |
|---|---|---|---|---|
| `web` | 정적/SPA asset | 낮음(압축/캐시 정책 영향) | 낮음 | cache-control, 404 |
| `config-api` | 앱 시작·새로고침마다 반복 호출 | feature rule 복잡하면 증가 | config snapshot | `/config` latency |
| `redis` | cache read/write 집중 | 단순 command는 낮음 | key 수·value 크기·eviction | memory usage, key count, hit/miss |
| `cache-writer` | 수업용 write | 낮음 | 없음 | write 증거 |

`config-api`가 단순해 보여도 **모든 브라우저가 시작 시점에 호출**하면 의외로 중요한 hot path가 된다 — 죽으면 앱이 설정을 못 받아 전체가 흔들릴 수 있다.

### profile — 늘 띄울 필요 없는 도구를 분리

`redis-cli`는 `profiles: ["tool"]`이라 평소엔 안 뜬다. 점검할 때만 켠다.

```bash
docker compose up -d                          # redis-cli 제외하고 기동
docker compose --profile tool run --rm redis-cli   # 점검용 일회성 실행 후 삭제 → PONG
```

운영에서 "디버그/마이그레이션/시드 같은 보조 컨테이너"를 평소 stack과 섞지 않고 profile로 떼어두는 패턴이다. `--rm`이 붙어 끝나면 컨테이너가 남지 않는다.

**`--profile`은 전역 플래그 — subcommand 앞에 온다.** `docker compose ps --profile tool`은 `unknown flag` 에러다. 위치가 중요하다.

```text
docker compose  --profile tool  ps      ← 맞음 (compose 바로 뒤)
docker compose  ps  --profile tool      ← 틀림 (unknown flag)
```

| 플래그 | 위치 | 예 |
|---|---|---|
| `--profile`, `-f`, `-p` | subcommand **앞**(전역) | `docker compose --profile tool ps` |
| `-a`, `-q`, `--format` | subcommand **뒤** | `docker compose ps -a` |

**`--profile tool ps`를 해도 redis-cli가 안 보일 수 있다.** `ps`는 **떠 있는 컨테이너만** 보여준다. profile 플래그는 "대상에 포함"하라는 뜻이지 없는 걸 만들지 않는다. 게다가 `redis-cli`는 `PING` 한 번 하고 바로 종료(`Exited`)하므로 `-a`를 줘야 보인다.

```bash
docker compose --profile tool up -d     # redis-cli 컨테이너 생성 (PING 후 Exited)
docker compose --profile tool ps -a     # Exited된 redis-cli까지 표시
```

| 명령 | 결과 |
|---|---|
| `docker compose --profile tool ps` | 안 띄웠으면 redis-cli **안 나옴**(정상) |
| `docker compose --profile tool up -d` | redis-cli 생성 (곧 Exited) |
| `docker compose --profile tool ps -a` | Exited까지 표시 |
| `docker compose --profile tool run --rm redis-cli` | 일회성 실행 → PONG → 자동 삭제(권장) |

핵심: profile service는 **`up`/`run`으로 켜야 존재하고, 단순 `ps`로는 안 생긴다.** 점검용이라 평소엔 일부러 안 떠 있는 게 의도된 동작이다.

### Cleanup 기준

```bash
docker compose down                  # container + network 정리
docker compose --profile tool down   # profile로 띄운 것까지 같이 정리
```

이 lab은 **volume이 없어 `down -v`가 필요 없다** — `down`만으로 cache까지 깨끗이 사라진다. (DB lab과의 차이.)

### 흔한 오해 / 실패

- cache는 app 안에 있다 → 별도 service(redis). app 재시작과 cache 수명은 분리된다.
- feature flag는 코드/이미지를 바꿔야 한다 → runtime env로 바꾼다(이미지 재빌드 X). 단 override되려면 compose에서 `${VAR}`로 열어둬야 함.
- redis도 `down -v` 해야 데이터가 지워진다 → 이 lab은 volume이 없어 `down`만으로 사라진다.
- `redis-cli`가 안 떠서 고장 → profile `tool`이라 의도적으로 제외된 것. `--profile tool`로 켠다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| env(`FEATURE_AI_REVIEW=true`) 바꿔도 `/config`에 반영 안 됨 | compose에 값이 하드코딩(`"false"`)돼 shell env가 override 못 함. `docker compose config`로 실제 적용값 확인 → interpolation(`${VAR}`)으로 바꿔야 외부 주입 가능 |
| `docker compose ps`에 `redis-cli`가 없음 | 고장 아님. `profiles: ["tool"]`이라 기본 제외. `--profile tool`을 줘야 등장 |
