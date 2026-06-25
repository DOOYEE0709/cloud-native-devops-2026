# 1교시: D1 Handoff 검증과 운영 관점 전환

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `ls week3/day2/labs/incident-scenarios` | D2 전용 사고 재현 script 4개 확인 (`01_ghost_pending_order.sh`, `02_backlog_drain.sh`, `03_poison_message.sh`, `04_duplicate_request.sh`) |
| D1 evidence 재분류 | `curl /api/orders`, `LLEN order-events`, `order-worker` log, `audit_logs`, `orders.status`를 D2 사고 비교 기준으로 다시 정리 |
| D1 정상 흐름 재실행 여부 | 하지 않음 — 정상 주문 생성 / worker log / queue 0은 D1 결과이며 D2에서 반복 금지 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Day 2는 무엇을 전제로 시작하는가? | `frontend->api->db`, `order-api->redis->order-worker->db` 등 D1의 정상 흐름을 이미 안다는 전제. D2는 그 정상 기준이 깨지는 상황을 만든다. |
| D1 evidence는 D2에서 어떻게 쓰이는가? | 정상 동작 증명이 아니라 사고 전후를 비교하는 기준 자료로 재분류한다. (예: `orders.status`는 `processed` 확인 → `pending`/duplicate/ghost row 탐지용) |
| DB commit은 됐는데 queue publish가 실패하면 왜 문제인가? | client는 실패를 봤는데 DB에는 상태가 남아 client 실패와 DB 상태가 어긋난다 (ghost pending). |
| incident-scenarios script의 목적은? | 정상 실행을 편하게 하는 게 아니라 사고를 재현하고 evidence를 묶어 보기 위한 script다. |
| HTTP 200이면 업무가 끝난 것인가? | 아니다. API 200이어도 내부 상태(DB/queue)와 어긋날 수 있어 user-visible success를 따로 판단해야 한다. |

## notes

### Day 2의 관점 전환

D1은 "정상 흐름을 설명"했고, D2는 "정상 기준이 깨지는 사고를 분석"한다. 같은 evidence를 다른 질문으로 읽는다.

```text
D1: 주문 API 호출 -> 로그 확인 -> 처리됨
D2: Redis 장애 중 주문 API 호출
    -> client는 실패, 그러나 DB에 pending row가 남았는지 확인
    -> queue event가 없으면 worker가 처리 못 한다는 결론
    -> outbox/idempotency/runbook 필요성 도출
```

### D1 Evidence를 운영 기준으로 재분류

| Evidence | D1 의미 | D2 의미 |
|---|---|---|
| `curl /api/orders` | 주문 API 동작 | 사고 후 주문 상태가 꼬였는지 비교 |
| `LLEN order-events` | queue 비어 있음 | backlog / event 유실 판단 |
| `order-worker` log | worker 처리함 | worker가 멈췄는지, error를 냈는지 판단 |
| `audit_logs` | 처리 이력 남음 | 어느 단계까지 실행됐는지 timeline 작성 |
| `orders.status` | `processed` 확인 | `pending`, duplicate, ghost row 탐지 |

### Day 2에서 보는 진짜 질문

| 질문 | 왜 중요한가 |
|---|---|
| DB commit 됐는데 queue publish 실패? | client 실패와 DB 상태가 어긋남 |
| worker 멈춘 동안 주문이 계속 들어오면? | backlog와 처리 지연 발생 |
| queue에 잘못된 message가 들어오면? | worker error, message 유실, DLQ 필요성 |
| 같은 요청이 두 번 들어오면? | request id만으로 중복 방지 안 됨 |
| API는 200인데 업무가 안 끝났으면? | user-visible success 판단 필요 |

### D2 전용 Lab script

| Script | 수업 역할 |
|---|---|
| `01_ghost_pending_order.sh` | DB commit과 queue publish 사이 장애 |
| `02_backlog_drain.sh` | worker 중지 중 backlog와 복구 |
| `03_poison_message.sh` | 잘못된 queue message와 DLQ 부재 |
| `04_duplicate_request.sh` | idempotency 없는 중복 요청 |

### 수업 진행 규칙

| 규칙 | 이유 |
|---|---|
| 정상 curl 반복 금지 | D1과 겹침 |
| 사고 전후 상태 비교 | 운영 판단이 됨 |
| HTTP 결과만 믿지 않기 | 내부 상태와 어긋날 수 있음 |
| DB와 queue를 같이 보기 | 업무 완료와 event 흐름을 분리 |
| 복구 명령 후 evidence 확인 | start 명령 자체는 복구 evidence가 아님 |

### 핵심

MSA 사고는 "API 200 = 정상"이 아니다. client 응답, DB 상태, queue 상태를 분리해서 보고, 정상 기준이 깨지는 경계를 evidence로 비교해 운영 판단을 내린다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
