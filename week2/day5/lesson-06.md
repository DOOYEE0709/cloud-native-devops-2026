# 6교시: 카카오형 메시징/worker template

> 실습 검증은 lab `week2/day5/labs/compose-architectures/05-queue-worker-db`(message-api(node, producer) + queue(redis) + worker(redis BRPOP) + db(postgres))로 진행했다.

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker compose config --services` | service 4개 — `queue`, `worker`, `db`, `message-api` |
| `docker compose up -d` | network 3개(`public_net`/`queue_net`/`data_net`)·volume(`pgdata`) 생성, container 4개 기동 |
| `docker compose ps` | `message-api`만 `0.0.0.0:18105->3000` 공개. `queue`/`worker`(redis), `db`는 내부 포트만 |
| `docker compose logs worker` (초기) | `worker waiting for jobs` — `BRPOP jobs 0`으로 job 대기 중(blocking) |
| `curl 'http://localhost:18105/publish?job=send-email:42'` | `{"service":"message-api","queued":"send-email:42","redis":":1"}` — `LPUSH jobs` 결과 list 길이 `1` |
| `curl 'http://localhost:18105/publish?job=send-push:7'` / `curl 'http://localhost:18105/publish?job=resize-image:99'` | 각각 `redis":1` — 즉시 queue에 적재 |
| `docker compose logs worker` (publish 후) | `jobs` / `send-email:42` / `send-push:7` / `resize-image:99` — worker가 BRPOP으로 순서대로 소비 |
| `docker compose exec queue redis-cli LLEN jobs` | `0` — worker가 다 꺼내 queue 비어있음 |
| `docker compose exec db psql -U postgres -d jobs -c "SELECT current_database();"` | `jobs` |
| **`docker compose stop worker`** 후 publish ×5 | 모두 **HTTP 200** — worker가 죽어도 API는 즉시 응답(decoupling) |
| 같은 상태 `LLEN jobs` | **5** — worker가 안 꺼내 backlog 쌓임 |
| `docker compose up -d worker` 후 `LLEN jobs` | **0** — 복구되자 밀린 5건을 FIFO로 소진(worker 로그에 `task-1`~`task-5`) |
| `docker compose down` | container 4개·network 3개 정리 (pgdata 보존) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 이 template은 무엇을 보여주나? | W1D4 메시징/스트리밍 사례. API가 **모든 일을 직접 끝내지 않고** queue에 job을 넣고(producer), worker가 queue에서 꺼내 처리(consumer)하는 **비동기(async) 구조**. |
| 동기 처리와 뭐가 다른가? | 동기면 API가 작업을 끝낼 때까지 사용자를 기다리게 한다. 여기선 API가 job을 queue에 **넣기만 하고 바로 200**을 준다. 무거운 처리는 worker가 뒤에서 한다 — 사용자 응답과 실제 처리가 **분리(decoupling)**된다. |
| producer/consumer는 어떻게 연결되나? | 직접 연결되지 않는다. **queue(redis)를 사이에 둔다.** message-api는 `LPUSH jobs <job>`로 넣고, worker는 `BRPOP jobs 0`으로 꺼낸다. 서로 상대를 모르고 queue만 안다. |
| `LPUSH` + `BRPOP`은 무슨 패턴인가? | redis list를 큐로 쓰는 것. 왼쪽으로 넣고(LPUSH) 오른쪽에서 꺼내면(BRPOP) **FIFO**(먼저 넣은 게 먼저 처리). `BRPOP ... 0`의 `0`은 "job 올 때까지 무한 대기(blocking)" — 그래서 worker가 바쁜 polling 없이 조용히 기다린다. |
| worker가 죽으면 job은 사라지나? | 아니다(실증). worker가 죽어도 publish는 200이고 job은 **queue에 backlog로 쌓인다**(`LLEN`=5). worker가 복구되면 밀린 걸 그대로 소진한다. queue가 **버퍼** 역할을 해서 일시적 worker 장애를 흡수한다. |
| 그럼 이 구조의 핵심 지표는? | HTTP 200이 아니다. **queue length(`LLEN jobs`)**다. 계속 늘면 "worker가 들어오는 속도를 못 따라간다 = worker capacity 부족" 신호다. |
| `db`는 이 lab에서 무슨 역할인가? | worker가 `data_net`으로 db에 붙어 **처리 결과를 기록하는 확장 구조**를 상정한 것(POSTGRES_DB=`jobs`). 이 lab의 worker는 BRPOP 로그까지만 보여주지만, network 배치상 worker→db 경로가 열려 있다. |

## notes

### 핵심 구조 — producer / queue / consumer (비동기)

지금까지(2~5교시)는 요청→응답이 한 줄로 끝나는 **동기** 구조였다. 6교시는 처음으로 **비동기**가 나온다: API는 job을 맡기고 바로 떠나고, 실제 처리는 worker가 뒤에서 한다.

```text
사용자 → message-api(18105) ──LPUSH──→ queue(redis) ──BRPOP──→ worker → (db)
        (job 넣고 바로 200)            (job 임시 보관)          (꺼내서 처리)
```

| Service | 역할 | 공개 범위 | network |
|---|---|---|---|
| `message-api` | HTTP producer, queue에 job 입력 (node) | host `18105` | `public_net`, `queue_net` |
| `queue` | Redis queue (job 임시 보관) | 내부만 | `queue_net` |
| `worker` | consumer, `BRPOP`으로 job 처리 | logs만 | `queue_net`, `data_net` |
| `db` | 처리 결과 저장 (확장 상정) | 내부만 | `data_net` |

network 배치가 경계를 만든다: `message-api`는 `queue_net`까지만(queue에 넣기), `worker`는 `queue_net`+`data_net`(queue에서 꺼내 db에 쓰기). **producer는 db를 모르고, db는 외부를 모른다.**

### producer와 consumer는 서로를 모른다 — queue가 사이에 (decoupling)

핵심은 message-api와 worker가 **직접 연결되지 않는다**는 것. 둘 다 `queue`만 안다.

```text
message-api:  LPUSH jobs <job>   # "queue에 넣었다", worker가 누군지 모름
worker:       BRPOP jobs 0       # "queue에서 꺼낸다", 누가 넣었는지 모름
```

이 분리가 주는 이점:
- **사용자 응답이 빠르다**: 무거운 작업(이메일 발송, 이미지 변환)을 기다리지 않고 "접수했다"만 200으로 즉시 반환.
- **독립 확장**: worker만 여러 개로 늘려 처리량을 올릴 수 있다(producer 안 건드리고).
- **장애 흡수**: worker가 잠깐 죽어도 job은 queue에 쌓여 있다가 복구 후 처리된다(아래 실증).

### worker가 죽어도 job은 안 사라진다 — queue는 버퍼 (실증)

`worker`만 멈추고 확인:

| 확인 | 결과 | 의미 |
|---|---|---|
| publish ×5 (worker 죽은 상태) | 모두 **HTTP 200** | API는 worker 생사와 무관하게 응답(decoupling) |
| `LLEN jobs` | **5** | 처리 못 한 job이 queue에 **backlog로 누적** |
| worker 복구 후 `LLEN jobs` | **0** | 밀린 5건을 FIFO로 소진(`task-1`~`task-5`) |

queue가 **완충(buffer)** 역할을 한다 — 일시적 worker 장애나 트래픽 폭주를 흡수한다. 동기 구조였다면 worker가 죽는 순간 사용자 요청이 바로 실패했겠지만, 여기선 큐에 쌓아두고 나중에 처리한다.

> 단, queue도 무한하지 않다(redis 메모리, 4교시). backlog가 끝없이 쌓이면 결국 메모리가 차고 job 유실/거부가 생긴다. "잠깐 죽음"은 흡수하지만 "계속 못 따라감"은 못 버틴다.

### 핵심 지표는 HTTP 200이 아니라 queue length

동기 서비스는 "200 나오면 정상"이지만, 비동기는 **200이 정상을 보장하지 않는다.** API가 200을 줘도 그건 "접수했다"일 뿐, job이 처리됐다는 뜻이 아니다.

```text
HTTP 200          → "job을 queue에 넣었다" (접수)
LLEN jobs 증가 중  → "worker가 못 따라간다" (처리 지연 경고)
worker logs       → "실제로 꺼내 처리하고 있나"
db 기록           → "처리 결과가 남았나"
```

그래서 이 구조의 장애 확인은 **web response만 보면 안 되고** queue length + worker logs + db까지 같이 봐야 한다. `LLEN jobs`가 계속 increase하면 worker를 늘리거나(scale out) 처리 로직을 최적화해야 한다는 신호다.

### LPUSH + BRPOP — redis list를 큐로

| 명령 | 동작 |
|---|---|
| `LPUSH jobs <job>` | list 왼쪽에 job 추가 (producer) |
| `BRPOP jobs 0` | list 오른쪽에서 꺼냄, 비어있으면 **무한 대기(blocking)** (consumer) |

왼쪽 넣고 오른쪽 꺼내니 **FIFO**(먼저 들어간 게 먼저 나감). `BRPOP`의 `B`는 blocking — job이 올 때까지 CPU를 안 쓰고 조용히 기다린다(바쁜 polling 회피). publish 응답의 `redis":1`은 LPUSH 후 list 길이다.

> 실무에선 redis list보다 전용 메시지 브로커(RabbitMQ, Kafka, AWS SQS/SNS)를 쓰는 경우가 많다. ack/재시도/순서보장/중복제거 같은 기능이 필요해서다. 이 lab은 "producer-queue-consumer"의 본질만 redis로 단순화한 것.

### 트래픽/부하 성향 노트

| Service | 트래픽 성향 | CPU 부하 | 메모리/상태 부하 | 먼저 볼 것 |
|---|---|---|---|---|
| `message-api` | job publish 몰림 | payload 검증/직렬화 | 짧은 request buffer | publish 성공률, latency |
| `queue` | enqueue/dequeue 집중 | redis command 자체는 낮음 | **backlog length, memory** | `LLEN jobs`, memory |
| `worker` | 사용자 직접 traffic 없음 | **job 처리 로직이 무거우면 가장 큼** | batch buffer, retry state | throughput, error log |
| `db` | 처리 결과 write | transaction, index update | WAL, buffer/cache, volume | write latency, lock |

사용자 traffic(`message-api`)과 background 처리(`worker`)의 부하가 **분리**된다. API가 빠르게 200을 줘도 worker가 밀리면 실제 업무는 지연된다 — 그래서 둘을 나눠 본다.

### Cleanup 기준

```bash
docker compose down       # container + network 정리 (pgdata 보존)
docker compose down -v    # named volume pgdata까지 삭제
```

`db`에 `pgdata` volume이 있어 `down`만으론 DB 데이터가 남는다(2/3교시와 동일). queue(redis)는 volume이 없어 컨테이너 제거 시 큐 내용이 사라진다(4교시 cache와 동일).

### 흔한 오해 / 실패

- HTTP 200이면 job 처리 완료 → 200은 "접수"일 뿐. 처리는 worker가 비동기로. 지표는 queue length.
- worker 죽으면 job 유실 → queue에 backlog로 쌓였다가 복구 후 처리(단, queue 메모리 한계까지만).
- producer가 worker를 직접 호출한다 → 둘은 서로 모르고 queue만 안다(decoupling).
- queue는 무한 버퍼다 → redis 메모리 한계가 있다. "잠깐 죽음"은 흡수해도 "계속 못 따라감"은 못 버틴다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| API는 200인데 처리가 안 되는 것 같다 | `LLEN jobs` 확인 → 계속 증가면 worker가 못 따라가는 것. `docker compose logs worker`로 worker가 살아 BRPOP 중인지, 처리 중 에러 나는지 확인 |
| worker 로그에 job이 안 보임 | worker가 죽었거나 `queue_net` 연결 문제. `docker compose ps`로 worker 상태, queue service name(`-h queue`) 접속 확인 |
