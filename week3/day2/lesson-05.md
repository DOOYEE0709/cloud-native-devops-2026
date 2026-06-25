# 5교시: Poison Message와 DLQ 필요성

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `cd week3/day2/labs/incident-scenarios` 후 `./03_poison_message.sh` | malformed payload를 queue에 주입해 worker 실패를 재현 |
| 사전 조건: `redis-cli LLEN order-events` == 0 | queue가 비어 있어야 실행 (backlog와 섞이지 않게) |
| `redis-cli LPUSH order-events "not-json-day2-poison-..."` | JSON이 아닌 poison message 주입 |
| `sleep 15` 후 `docker compose logs order-worker \| grep worker_error` | worker가 파싱 실패 → `worker_error` log 남김 |
| `redis-cli LLEN order-events` (소비 후) | queue length 0 — message가 소비된 뒤 사라짐(별도 보관 없음) |
| `audit_logs` 확인 | 업무 event 없음 — 처리 단계까지 못 감 |

<details>
<summary>`./03_poison_message.sh` 전체 실행 로그</summary>

```text
mac@macui-MacBookPro incident-scenarios % ./03_poison_message.sh
[scenario] Poison message without DLQ
[payload] not-json-day2-poison-1782375046
 Container msa-demo-catalog-api-1 Stopping 
 Container msa-demo-order-api-1 Stopping 
 Container msa-demo-order-worker-1 Stopping 
 Container msa-demo-frontend-1 Stopping 
 Container msa-demo-worker-1 Stopping 
 Container msa-demo-frontend-1 Stopped 
 Container msa-demo-frontend-1 Removing 
 Container msa-demo-frontend-1 Removed 
 Container msa-demo-catalog-api-1 Stopped 
 Container msa-demo-catalog-api-1 Removing 
 Container msa-demo-catalog-api-1 Removed 
 Container msa-demo-worker-1 Stopped 
 Container msa-demo-worker-1 Removing 
 Container msa-demo-worker-1 Removed 
 Container msa-demo-api-1 Stopping 
 Container msa-demo-order-worker-1 Stopped 
 Container msa-demo-order-worker-1 Removing 
 Container msa-demo-order-worker-1 Removed 
 Container msa-demo-order-api-1 Stopped 
 Container msa-demo-order-api-1 Removing 
 Container msa-demo-order-api-1 Removed 
 Container msa-demo-redis-1 Stopping 
 Container msa-demo-redis-1 Stopped 
 Container msa-demo-redis-1 Removing 
 Container msa-demo-redis-1 Removed 
 Container msa-demo-api-1 Stopped 
 Container msa-demo-api-1 Removing 
 Container msa-demo-api-1 Removed 
 Container msa-demo-db-1 Stopping 
 Container msa-demo-db-1 Stopped 
 Container msa-demo-db-1 Removing 
 Container msa-demo-db-1 Removed 
 Network msa-demo_msa-net Removing 
 Network msa-demo_msa-net Removed 
 Image msa-demo-catalog-api Building 
 Image msa-demo-api Building 
 Image msa-demo-worker Building 
 Image msa-demo-order-worker Building 
 Image msa-demo-order-api Building 
 Image msa-demo-catalog-api Built 
 Image msa-demo-api Built 
 Image msa-demo-order-api Built 
 Image msa-demo-order-worker Built 
 Image msa-demo-worker Built 
 Network msa-demo_msa-net Creating 
 Network msa-demo_msa-net Created 
 Container msa-demo-db-1 Creating 
 Container msa-demo-redis-1 Creating 
 Container msa-demo-redis-1 Created 
 Container msa-demo-db-1 Created 
 Container msa-demo-order-worker-1 Creating 
 Container msa-demo-order-api-1 Creating 
 Container msa-demo-catalog-api-1 Creating 
 Container msa-demo-api-1 Creating 
 Container msa-demo-order-api-1 Created 
 Container msa-demo-order-worker-1 Created 
 Container msa-demo-catalog-api-1 Created 
 Container msa-demo-api-1 Created 
 Container msa-demo-frontend-1 Creating 
 Container msa-demo-worker-1 Creating 
 Container msa-demo-worker-1 Created 
 Container msa-demo-frontend-1 Created 
 Container msa-demo-redis-1 Starting 
 Container msa-demo-db-1 Starting 
 Container msa-demo-db-1 Started 
 Container msa-demo-db-1 Waiting 
 Container msa-demo-db-1 Waiting 
 Container msa-demo-redis-1 Started 
 Container msa-demo-db-1 Waiting 
 Container msa-demo-db-1 Waiting 
 Container msa-demo-db-1 Healthy 
 Container msa-demo-api-1 Starting 
 Container msa-demo-db-1 Healthy 
 Container msa-demo-catalog-api-1 Starting 
 Container msa-demo-db-1 Healthy 
 Container msa-demo-order-api-1 Starting 
 Container msa-demo-db-1 Healthy 
 Container msa-demo-order-worker-1 Starting 
 Container msa-demo-order-api-1 Started 
 Container msa-demo-api-1 Started 
 Container msa-demo-frontend-1 Starting 
 Container msa-demo-worker-1 Starting 
 Container msa-demo-order-worker-1 Started 
 Container msa-demo-catalog-api-1 Started 
 Container msa-demo-frontend-1 Started 
 Container msa-demo-worker-1 Started 

[1] Push malformed queue message
1

[2] Worker consumes it and logs an error
order-worker-1  | {"service": "order-worker", "event": "worker_error", "request_id": "worker-1782375073", "error": "Expecting value: line 1 column 1 (char 0)"}

[3] Queue length after poison message
0

[4] Audit rows created after poison message
 service_name | request_id | event | created_at 
--------------+------------+-------+------------
(0 rows)


[note] In this teaching worker, malformed messages are consumed and lost. A real system needs DLQ/retry metadata.
```

</details>

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| poison message란? | worker가 파싱/처리할 수 없는 잘못된 message (예: `not-json-...`). schema mismatch·배포 불일치·수동 주입 실수로 발생. |
| message가 소비된 뒤 실패하면 evidence는? | DLQ가 없으면 queue에서 사라져(LLEN 0) 재처리·추적이 어렵다 (silent loss). |
| `worker_error`만 남고 audit row가 없으면? | worker가 message 처리에 실패했고 업무 처리 단계까지 가지 못했다는 뜻. |
| 이 실습 worker의 한계는? | DLQ가 없어 실패 message가 격리되지 않고 사라진다 — "없는 것" 자체가 학습 포인트. |
| queue를 쓰면 자동으로 안정적인가? | 아니다. retry policy, DLQ, schema validation, idempotent 처리가 함께 필요하다. |

## notes

### 사고 시나리오

```text
정상 message: {"order_id": 12, "request_id": "day2-..."}
poison message: not-json-day2-poison
```

worker는 queue에서 message를 꺼내 JSON 파싱을 시도 → 실패 시 error log. 이 교육용 worker엔 DLQ가 없어 message가 별도 보관되지 않는다.

### 봐야 할 Evidence와 해석

| Evidence | 질문 | 이번 결과 |
|---|---|---|
| worker log | `worker_error` 남았나 | 남음 |
| queue length | poison이 남아 있나 | 0 (사라짐) |
| audit_logs | 업무 event로 기록됐나 | 없음 |
| request id | 추적 가능한 id 있나 | 없음 (추적 어려움) |

### request_id가 "있는데도" 추적이 안 되는 이유

로그엔 `"request_id": "worker-1782364829"`가 찍혀 있지만, 이건 **진짜 request_id가 아니라 worker가 급조한 placeholder**다. `worker.py` 흐름:

```python
payload = client.rpop(QUEUE_NAME)        # "not-json-..." 꺼냄
event = json.loads(payload)              # ← 여기서 예외 발생 (JSON 아님)
request_id = event.get("request_id", …)  # ← 도달 못 함
...
except Exception as exc:
    log("worker_error", f"worker-{int(time.time())}", error=str(exc))  # timestamp로 가짜 id
```

| 이유 | 설명 |
|---|---|
| payload에 id가 없음 | `not-json-...`은 그냥 문자열, 추출할 필드 자체가 없다 |
| 추출 전에 죽음 | `json.loads()`에서 예외 → `event.get("request_id")` 실행조차 안 됨 |
| except가 가짜 id 생성 | `f"worker-{int(time.time())}"` = 현재 timestamp를 request_id 자리에 박음 |

→ request_id 칸은 채워졌지만 **어느 주문이 깨졌는지와 무관한 값**이다. 그래서 schema validation(무방비 `json.loads` 전 검증)과 DLQ(원본 payload 보존)가 필요하다. 지금은 payload 원문도 안 남고 사라진다.

### 왜 위험한가

| 위험 | 설명 |
|---|---|
| silent loss | 실패 message가 사라져 재처리 불가 |
| 반복 실패 | 같은 message가 계속 worker를 실패시킬 수 있음 |
| backlog blockage | queue 종류에 따라 뒤 message 처리가 막힐 수 있음 |
| 원인 추적 어려움 | request id·payload metadata 없으면 조사 어려움 |

### 필요한 설계

| 설계 | 목적 |
|---|---|
| schema validation | 처리 전에 message 형태 검증 |
| retry metadata | 몇 번 실패했는지 기록 |
| DLQ | 반복 실패 message를 별도 queue로 격리 |
| error reason | 실패 원인 저장 |
| alert | DLQ 증가·worker error rate 감지 |

### Retry / Backoff / DLQ vs Container Restart

retry는 **두 레벨**이 섞이기 쉽다. 분리해서 봐야 한다.

#### 1) Message 레벨 retry

worker가 message 처리에 실패했을 때.

```text
즉시 재시도: 실패 -> 재시도 -> 실패 ...   (실패하는 의존성을 계속 두들김)
backoff:    실패 -> 1s -> 2s -> 4s ...    (회복할 시간을 줌)
```

| 실패 종류 | retry가 의미 있나 | 처리 |
|---|---|---|
| 일시적 실패 (DB 잠깐 바쁨, 네트워크 blip) | 있음 | interval/backoff 주고 재시도 |
| poison message (JSON 깨짐 등) | 없음 (영원히 실패) | N회 실패 후 **DLQ로 격리** |

핵심: N회 실패한 message는 **worker를 내리는 게 아니라 DLQ로 빼둔다.** worker를 내리면 멀쩡한 다른 message까지 못 받는다. DLQ는 "이 한 건만 격리하고 나머지는 계속 처리"하는 장치. (이 실습 worker엔 DLQ가 없어 silent loss 발생)

#### 2) Container / Process 레벨 restart

worker 프로세스가 죽어 컨테이너가 내려간 경우. "다시 올리려면 수동인가?"가 여기에 해당.

| 정책 | 동작 | 복구 |
|---|---|---|
| `restart: on-failure:3` (Docker) | 3회 재시작 후 **포기** | 수동 (번거로움) |
| `restart: always` / K8s 기본 | 계속 재시작 시도 | 자동 |
| K8s **CrashLoopBackOff** | 재시작하되 간격을 점점 늘림(10s→20s→40s…최대 5분) | 자동 (의존성 복구되면 스스로 회복) |

고정 횟수(`on-failure:3`)는 포기 후 수동 복구가 필요해 번거롭다. 그래서 K8s는 포기하지 않고 **backoff 간격만 늘리며 계속 재시도**해 의존성이 살아나면 사람 손 없이 다시 붙는다.

#### 한 줄 정리

```text
즉시 retry          X  ->  interval/backoff                   O  (일시적 실패 회복 시간 확보)
N회 실패한 message  X  ->  DLQ로 격리                            O
N회 실패한 process  X  ->  backoff 자동 재시도(CrashLoopBackOff)  O
```

### 실무형 Runbook

| 단계 | 명령/확인 | 판단 |
|---|---|---|
| 1 | worker error rate 확인 | poison message 가능성 |
| 2 | queue depth 확인 | backlog 동반 여부 |
| 3 | 실패 payload 샘플 확인 | schema mismatch 여부 |
| 4 | DLQ 확인 | 격리된 message 수 |
| 5 | 재처리 가능성 판단 | idempotency·데이터 상태 확인 |

현재 실습엔 DLQ가 없다. 그래서 "없는 것"이 학습 포인트다.

### 운영 리포트 문장

```text
Redis queue에 malformed payload를 주입하자 order-worker가 worker_error를 남겼다.
이후 order-events queue length는 0이 되었고, audit_logs에는 업무 event가 남지 않았다.
현재 worker에는 DLQ가 없어 실패 message를 별도로 추적하거나 재처리하기 어렵다.
```

### 핵심

queue를 쓴다고 자동으로 안정적인 것이 아니다.

```text
queue + worker
  needs retry policy
  needs DLQ
  needs schema validation
  needs idempotent processing
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
