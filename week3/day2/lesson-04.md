# 4교시: Worker Backlog와 Drain 관찰

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `cd week3/day2/labs/incident-scenarios` 후 `COUNT=8 ./02_backlog_drain.sh` | worker 중지 → 주문 8개 접수 → backlog → 복구 → drain을 재현 (COUNT로 부하 조절) |
| script 내부: `docker compose stop order-worker` | 유일한 소비자인 worker를 중지 |
| `for i in seq 1 COUNT: curl POST .../api/orders` | worker 정지 중 주문 8건 생성 (각 `x-request-id` 부여) |
| `redis-cli LLEN order-events` (복구 전) | queue length = 8 (주문 수만큼 쌓임 → worker가 유일 소비자) |
| `psql ... orders where request_id like 'PREFIX-%'` | 8건 모두 `pending` 상태 |
| `docker compose start order-worker` 후 `t+1~t+20s LLEN` 반복 | 복구 후 queue length가 점차 감소하는 drain 관찰 |
| `wait+Ns LLEN` 루프 (0 될 때까지, max) | backlog drain 완료 → queue length 0 |
| `psql ... orders` (복구 후) | 8건 모두 `processed`, `processed_at` 기록됨 |

<details>
<summary>`COUNT=8 ./02_backlog_drain.sh` 전체 실행 로그</summary>

```text
mac@macui-MacBookPro incident-scenarios % COUNT=8 ./02_backlog_drain.sh
[scenario] Worker backlog and drain
[prefix] day2-backlog-1782374904
[count] 8
 Container msa-demo-worker-1 Stopping 
 Container msa-demo-frontend-1 Stopping 
 Container msa-demo-order-api-1 Stopping 
 Container msa-demo-catalog-api-1 Stopping 
 Container msa-demo-order-worker-1 Stopping 
 Container msa-demo-frontend-1 Stopped 
 Container msa-demo-frontend-1 Removing 
 Container msa-demo-frontend-1 Removed 
 Container msa-demo-order-api-1 Stopped 
 Container msa-demo-order-api-1 Removing 
 Container msa-demo-order-api-1 Removed 
 Container msa-demo-order-worker-1 Stopped 
 Container msa-demo-order-worker-1 Removing 
 Container msa-demo-order-worker-1 Removed 
 Container msa-demo-redis-1 Stopping 
 Container msa-demo-catalog-api-1 Stopped 
 Container msa-demo-catalog-api-1 Removing 
 Container msa-demo-catalog-api-1 Removed 
 Container msa-demo-worker-1 Stopped 
 Container msa-demo-worker-1 Removing 
 Container msa-demo-worker-1 Removed 
 Container msa-demo-api-1 Stopping 
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
 Image msa-demo-worker Building 
 Image msa-demo-api Building 
 Image msa-demo-order-worker Building 
 Image msa-demo-order-api Building 
 Image msa-demo-order-worker Built 
 Image msa-demo-api Built 
 Image msa-demo-worker Built 
 Image msa-demo-catalog-api Built 
 Image msa-demo-order-api Built 
 Network msa-demo_msa-net Creating 
 Network msa-demo_msa-net Created 
 Container msa-demo-redis-1 Creating 
 Container msa-demo-db-1 Creating 
 Container msa-demo-db-1 Created 
 Container msa-demo-api-1 Creating 
 Container msa-demo-catalog-api-1 Creating 
 Container msa-demo-redis-1 Created 
 Container msa-demo-order-api-1 Creating 
 Container msa-demo-order-worker-1 Creating 
 Container msa-demo-catalog-api-1 Created 
 Container msa-demo-order-api-1 Created 
 Container msa-demo-order-worker-1 Created 
 Container msa-demo-api-1 Created 
 Container msa-demo-frontend-1 Creating 
 Container msa-demo-worker-1 Creating 
 Container msa-demo-worker-1 Created 
 Container msa-demo-frontend-1 Created 
 Container msa-demo-db-1 Starting 
 Container msa-demo-redis-1 Starting 
 Container msa-demo-db-1 Started 
 Container msa-demo-db-1 Waiting 
 Container msa-demo-db-1 Waiting 
 Container msa-demo-redis-1 Started 
 Container msa-demo-db-1 Waiting 
 Container msa-demo-db-1 Waiting 
 Container msa-demo-db-1 Healthy 
 Container msa-demo-db-1 Healthy 
 Container msa-demo-db-1 Healthy 
 Container msa-demo-api-1 Starting 
 Container msa-demo-order-worker-1 Starting 
 Container msa-demo-catalog-api-1 Starting 
 Container msa-demo-db-1 Healthy 
 Container msa-demo-order-api-1 Starting 
 Container msa-demo-catalog-api-1 Started 
 Container msa-demo-order-worker-1 Started 
 Container msa-demo-order-api-1 Started 
 Container msa-demo-api-1 Started 
 Container msa-demo-frontend-1 Starting 
 Container msa-demo-worker-1 Starting 
 Container msa-demo-frontend-1 Started 
 Container msa-demo-worker-1 Started 
 Container msa-demo-order-worker-1 Stopping 
 Container msa-demo-order-worker-1 Stopped 

[1] Create multiple orders while worker is stopped
created day2-backlog-1782374904-1
created day2-backlog-1782374904-2
created day2-backlog-1782374904-3
created day2-backlog-1782374904-4
created day2-backlog-1782374904-5
created day2-backlog-1782374904-6
created day2-backlog-1782374904-7
created day2-backlog-1782374904-8

[2] Queue length before recovery
8

[3] Pending orders before recovery
 id | status  |        request_id         | processed_at 
----+---------+---------------------------+--------------
  3 | pending | day2-backlog-1782374904-1 | 
  4 | pending | day2-backlog-1782374904-2 | 
  5 | pending | day2-backlog-1782374904-3 | 
  6 | pending | day2-backlog-1782374904-4 | 
  7 | pending | day2-backlog-1782374904-5 | 
  8 | pending | day2-backlog-1782374904-6 | 
  9 | pending | day2-backlog-1782374904-7 | 
 10 | pending | day2-backlog-1782374904-8 | 
(8 rows)


[4] Start worker and observe drain
 Container msa-demo-db-1 Waiting 
 Container msa-demo-db-1 Healthy 
 Container msa-demo-order-worker-1 Starting 
 Container msa-demo-order-worker-1 Started 
t+1s queue_length=8
t+2s queue_length=8
t+3s queue_length=8
t+4s queue_length=8
t+5s queue_length=8
t+6s queue_length=8
t+7s queue_length=8
t+8s queue_length=8
t+9s queue_length=8
t+10s queue_length=8
t+11s queue_length=7
t+12s queue_length=7
t+13s queue_length=7
t+14s queue_length=7
t+15s queue_length=7
t+16s queue_length=7
t+17s queue_length=7
t+18s queue_length=7
t+19s queue_length=7
t+20s queue_length=7

[5] Wait until backlog is drained, max 130s
wait+1s queue_length=7
wait+2s queue_length=6
wait+3s queue_length=6
wait+4s queue_length=6
wait+5s queue_length=6
wait+6s queue_length=6
wait+7s queue_length=6
wait+8s queue_length=6
wait+9s queue_length=6
wait+10s queue_length=6
wait+11s queue_length=6
wait+12s queue_length=6
wait+13s queue_length=5
wait+14s queue_length=5
wait+15s queue_length=5
wait+16s queue_length=5
wait+17s queue_length=5
wait+18s queue_length=5
wait+19s queue_length=5
wait+20s queue_length=5
wait+21s queue_length=5
wait+22s queue_length=5
wait+23s queue_length=5
wait+24s queue_length=4
wait+25s queue_length=4
wait+26s queue_length=4
wait+27s queue_length=4
wait+28s queue_length=4
wait+29s queue_length=4
wait+30s queue_length=4
wait+31s queue_length=4
wait+32s queue_length=4
wait+33s queue_length=4
wait+34s queue_length=3
wait+35s queue_length=3
wait+36s queue_length=3
wait+37s queue_length=3
wait+38s queue_length=3
wait+39s queue_length=3
wait+40s queue_length=3
wait+41s queue_length=3
wait+42s queue_length=3
wait+43s queue_length=3
wait+44s queue_length=3
wait+45s queue_length=2
wait+46s queue_length=2
wait+47s queue_length=2
wait+48s queue_length=2
wait+49s queue_length=2
wait+50s queue_length=2
wait+51s queue_length=2
wait+52s queue_length=2
wait+53s queue_length=2
wait+54s queue_length=2
wait+55s queue_length=1
wait+56s queue_length=1
wait+57s queue_length=1
wait+58s queue_length=1
wait+59s queue_length=1
wait+60s queue_length=1
wait+61s queue_length=1
wait+62s queue_length=1
wait+63s queue_length=1
wait+64s queue_length=1
wait+65s queue_length=1
wait+66s queue_length=0

[6] Orders after recovery
 id |  status   |        request_id         |         processed_at   
----+-----------+---------------------------+-------------------------------
  3 | processed | day2-backlog-1782374904-1 | 2026-06-25 08:08:54.943632+00
  4 | processed | day2-backlog-1782374904-2 | 2026-06-25 08:09:06.97256+00
  5 | processed | day2-backlog-1782374904-3 | 2026-06-25 08:09:18.998032+00
  6 | processed | day2-backlog-1782374904-4 | 2026-06-25 08:09:31.021257+00
  7 | processed | day2-backlog-1782374904-5 | 2026-06-25 08:09:43.047355+00
  8 | processed | day2-backlog-1782374904-6 | 2026-06-25 08:09:55.078955+00
  9 | processed | day2-backlog-1782374904-7 | 2026-06-25 08:10:07.109447+00
 10 | processed | day2-backlog-1782374904-8 | 2026-06-25 08:10:19.143099+00
(8 rows)
```

</details>

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| worker 중지 중 queue length가 주문 수만큼 증가하면? | worker가 유일한 소비자였다는 뜻이다. |
| backlog의 정의는? | `backlog = 들어온 작업 수 - 처리된 작업 수`. queue depth로 체감한다. |
| 복구 후 queue length가 0으로 줄면? | backlog drain 성공 — 밀린 작업이 모두 처리됨. |
| worker를 2개로 늘리면 backlog가 더 빨리 줄어드는가? | 처리량은 늘 수 있으나, 같은 event 중복 처리 방지·idempotent DB update·순서 보장 약화를 함께 고려해야 한다. |
| queue length 1이면 무조건 장애인가? | 아니다. 순간 burst는 정상일 수 있다. 중요한 건 지속 시간과 증가 속도다. |
| 이 사고를 무엇이라 부르는가? | API 접수는 살아 있고 비동기 처리만 지연된 delayed failure. |

## notes

### D1과 다른 점

```text
worker down
  -> 주문 여러 개 접수
  -> queue backlog 증가
  -> pending orders 증가
  -> worker 복구
  -> queue drain
  -> processed로 전환
```

단일 정상 처리 확인이 아니라 backlog와 recovery dynamics를 본다.

### 관찰 포인트와 해석

| Evidence | 질문 | 이번 결과 |
|---|---|---|
| queue length before recovery | 몇 개 쌓였나 | 8 |
| pending orders | 얼마나 밀렸나 | 8건 pending |
| t+1~t+5 queue length | 얼마나 빨리 줄어드나 | 점진적 감소 |
| processed orders | 최종 완료됐나 | 8건 processed |

| 관찰 | 운영 의미 |
|---|---|
| queue length가 주문 수만큼 증가 | worker가 유일 소비자 |
| 복구 후 0으로 감소 | drain 성공 |
| 일부 pending 유지 | 처리 실패 또는 처리량 부족 |
| worker error 반복 | DB/Redis/payload 문제 가능 |

### 처리량 관점 — queue length는 단순 숫자가 아니다

| 지표 | 의미 |
|---|---|
| queue depth | 현재 대기 중인 작업 수 |
| drain rate | 복구 후 초당 처리 작업 수 |
| oldest message age | 가장 오래 기다린 작업의 대기 시간 |
| worker error rate | 처리 실패 비율 |

현재 실습은 단순 Redis list라 모든 지표를 만들진 않지만 `LLEN` 변화만으로 backlog/drain 개념을 체감할 수 있다.

### Worker scale out 실험

```bash
cd week3/day1/labs/msa-demo
docker compose up -d --scale order-worker=2
docker compose ps order-worker
```

| 주의점 | 설명 |
|---|---|
| 처리량 증가 가능 | queue 소비자가 많아짐 |
| 중복 처리 안전성 필요 | 같은 event가 두 번 처리되면 안 됨 |
| DB update가 idempotent해야 함 | 재시도·worker crash 고려 |
| 처리 순서 보장 약화 | 병렬 처리에서 순서가 흐트러질 수 있음 |

### Alert 기준

| 상황 | 판단 |
|---|---|
| 순간 1~2개 쌓였다가 바로 0 | 정상 burst |
| 계속 증가 | 처리량 부족 또는 worker 장애 |
| 일정 값 이상 오래 유지 | alert 후보 |
| 업무 SLA 초과 | 사용자 영향 발생 |

### 운영 리포트 문장

```text
order-worker 중지 중 COUNT=8 주문을 생성하자 Redis order-events queue length가 8로 증가했다.
orders table에는 동일 prefix의 주문이 pending 상태로 남았다.
order-worker 복구 후 queue length가 0으로 감소했고, 주문 상태가 processed로 변경되었다.
이는 API 접수 경로는 살아 있으나 비동기 처리 경로가 지연된 delayed failure다.
```

### 핵심

worker 장애는 "API 장애"처럼 크게 보이지 않을 수 있다. 그래서 queue backlog 지표가 필요하다.

```text
API success + queue backlog 증가 = 업무 지연 가능성
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
