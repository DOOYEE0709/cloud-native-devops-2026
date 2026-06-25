# 2교시: Ghost Pending Order - Client 실패와 DB 상태 불일치

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `cd week3/day2/labs/incident-scenarios` 후 `./01_ghost_pending_order.sh` | Redis 중지 상태에서 주문 생성 사고를 재현하는 script 실행 |
| script 내부: `docker compose up --build -d` → `docker compose stop redis` | stack 실행 후 Redis만 중지해 publish 실패 조건을 만듦 |
| `curl -i -X POST -H "x-request-id: ${REQ_ID}" .../api/orders` | client는 실패 응답(503 등)을 받음 |
| `psql ... select ... from orders where request_id=...` | client 실패에도 DB에 동일 request_id의 `pending` row가 존재 |
| `docker compose start redis` 후 `redis-cli LLEN order-events` | Redis 복구 후에도 queue length 0 — 처리할 event 없음 |
| `psql ... from audit_logs where request_id=...` | `order_created`만 있고 `order_processed`는 없음 |
| `docker compose start order-worker` | stack 재사용 가능하도록 worker 재기동 |

<details>
<summary>`./01_ghost_pending_order.sh` 전체 실행 로그</summary>

```text
mac@macui-MacBookPro incident-scenarios % bash 01_ghost_pending_order.sh
[scenario] Redis down during order creation
[request_id] day2-ghost-pending-1782373279

[1] Start stack
 Container msa-demo-catalog-api-1 Stopping 
 Container msa-demo-order-worker-1 Stopping 
 Container msa-demo-order-api-1 Stopping 
 Container msa-demo-worker-1 Stopping 
 Container msa-demo-frontend-1 Stopping 
 Container msa-demo-frontend-1 Stopped 
 Container msa-demo-frontend-1 Removing 
 Container msa-demo-frontend-1 Removed 
 Container msa-demo-worker-1 Stopped 
 Container msa-demo-worker-1 Removing 
 Container msa-demo-worker-1 Removed 
 Container msa-demo-api-1 Stopping 
 Container msa-demo-catalog-api-1 Stopped 
 Container msa-demo-catalog-api-1 Removing 
 Container msa-demo-catalog-api-1 Removed 
 Container msa-demo-order-api-1 Stopped 
 Container msa-demo-order-api-1 Removing 
 Container msa-demo-order-api-1 Removed 
 Container msa-demo-order-worker-1 Stopped 
 Container msa-demo-order-worker-1 Removing 
 Container msa-demo-order-worker-1 Removed 
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
 Image msa-demo-order-api Building 
 Image msa-demo-api Building 
 Image msa-demo-catalog-api Building 
 Image msa-demo-worker Building 
 Image msa-demo-order-worker Building 
 Image msa-demo-api Built 
 Image msa-demo-order-api Built 
 Image msa-demo-order-worker Built 
 Image msa-demo-worker Built 
 Image msa-demo-catalog-api Built 
 Network msa-demo_msa-net Creating 
 Network msa-demo_msa-net Created 
 Container msa-demo-db-1 Creating 
 Container msa-demo-redis-1 Creating 
 Container msa-demo-redis-1 Created 
 Container msa-demo-db-1 Created 
 Container msa-demo-api-1 Creating 
 Container msa-demo-order-worker-1 Creating 
 Container msa-demo-order-api-1 Creating 
 Container msa-demo-catalog-api-1 Creating 
 Container msa-demo-order-worker-1 Created 
 Container msa-demo-api-1 Created 
 Container msa-demo-frontend-1 Creating 
 Container msa-demo-worker-1 Creating 
 Container msa-demo-catalog-api-1 Created 
 Container msa-demo-order-api-1 Created 
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
 Container msa-demo-catalog-api-1 Starting 
 Container msa-demo-db-1 Healthy 
 Container msa-demo-api-1 Starting 
 Container msa-demo-db-1 Healthy 
 Container msa-demo-order-worker-1 Starting 
 Container msa-demo-db-1 Healthy 
 Container msa-demo-order-api-1 Starting 
 Container msa-demo-order-worker-1 Started 
 Container msa-demo-api-1 Started 
 Container msa-demo-frontend-1 Starting 
 Container msa-demo-worker-1 Starting 
 Container msa-demo-catalog-api-1 Started 
 Container msa-demo-order-api-1 Started 
 Container msa-demo-worker-1 Started 
 Container msa-demo-frontend-1 Started 

[2] Stop Redis before order request
 Container msa-demo-redis-1 Stopping 
 Container msa-demo-redis-1 Stopped 

[3] Client request while Redis is down
HTTP/1.0 503 Service Unavailable
Server: BaseHTTP/0.6 Python/3.12.13
Date: Thu, 25 Jun 2026 07:41:36 GMT
content-type: application/json; charset=utf-8
content-length: 149

{
  "service": "order-api",
  "request_id": "day2-ghost-pending-1782373279",
  "error": "Error -2 connecting to redis:6379. Name does not resolve."
}
[4] Order row may already exist even when client saw failure
 id | status  |          request_id           |          created_at           | processed_at 
----+---------+-------------------------------+-------------------------------+--------------
 13 | pending | day2-ghost-pending-1782373279 | 2026-06-25 07:41:36.301723+00 | 
(1 row)


[5] Recover Redis
 Container msa-demo-redis-1 Starting 
 Container msa-demo-redis-1 Started 

[6] Queue length after Redis recovery
0

[7] Audit rows for this request
 service_name |          request_id           |     event     |          created_at           
--------------+-------------------------------+---------------+-------------------------------
 order-api    | day2-ghost-pending-1782373279 | order_created | 2026-06-25 07:41:36.301723+00
(1 row)


[cleanup] Keep stack usable
 Container msa-demo-db-1 Waiting 
 Container msa-demo-db-1 Healthy
```

</details>

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| ghost pending order란 무엇인가? | DB commit은 끝났지만 Redis publish가 실패해, client는 실패를 봤는데 DB에는 처리할 수 없는 pending 주문이 남은 상태. |
| client가 503을 받으면 DB는 rollback된 것인가? | 아니다. `client failure != DB rollback`. DB insert/commit은 이미 끝났을 수 있다. |
| 왜 worker가 이 주문을 처리하지 못하는가? | DB에는 row가 있지만 Redis queue에 event가 없어(LLEN 0) worker가 consume할 대상이 없다. |
| 근본 원인은 무엇인가? | DB commit과 Redis LPUSH가 하나의 atomic transaction이 아니라서, DB는 성공하고 Redis는 실패할 수 있다. |
| 사용자가 다시 주문 버튼을 누르면? | idempotency 제어가 없으면 중복 주문이 생길 수 있다. |
| 운영자가 하면 안 되는 단정은? | "실패했으니 아무 일도 없다"는 단정. 내부에는 pending 흔적이 남아 있다. |

## notes

### 사고 시나리오 흐름

```text
1. order-api가 DB에 주문 생성
2. DB commit 완료
3. Redis queue publish 단계에서 실패
4. client는 실패 응답을 봄
5. 그러나 DB에는 pending 주문이 남음
6. queue event가 없어 worker가 처리 불가
```

### 봐야 할 Evidence와 해석

| Evidence | 질문 | 이번 결과 |
|---|---|---|
| HTTP response | 성공/실패? | client 503 (실패로 인식) |
| `orders` row | DB에 남았는가? | pending row 존재 |
| `orders.status` | `pending`인가? | `pending` |
| Redis `LLEN` | 처리할 event 있는가? | 0 (없음) |
| `audit_logs` | `order_created`만 있는가? | `order_created`만, `order_processed` 없음 |

### 왜 생기는가

```text
DB insert/commit
  -> Redis LPUSH      <- 여기서 실패 가능
  -> response
```

DB commit과 Redis publish가 atomic하지 않다. 둘 사이에 transaction boundary 문제가 있다.

### 현실적인 해결책

| 해결책 | 설명 |
|---|---|
| outbox pattern | DB transaction 안에 발행할 event를 같이 저장하고 별도 publisher가 queue로 발행 |
| compensating job | 오래된 pending 주문을 찾아 재발행/취소 |
| idempotency key | 재시도해도 중복 주문이 생기지 않도록 제어 |
| reconciliation | DB 상태와 queue/audit 상태를 주기적으로 대조 |

### 운영 리포트 문장

```text
request_id=... 주문 요청은 Redis 중지 상태에서 client에 실패 응답을 반환했다.
그러나 orders table에는 동일 request_id의 pending row가 생성되어 있었고,
Redis queue에는 처리 대기 event가 없었다.
따라서 client failure와 DB state가 불일치하며,
worker가 자동 처리할 수 없는 ghost pending order 상태다.
```

### 핵심

HTTP 실패는 "아무 일도 일어나지 않았다"는 뜻이 아니다. MSA는 외부 dependency가 분리돼 있어 중간 성공/중간 실패 상태를 반드시 고려해야 한다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
