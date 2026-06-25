# 6교시: Duplicate Request와 Idempotency Gap

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `cd week3/day2/labs/incident-scenarios` 후 `./04_duplicate_request.sh` | 같은 `request_id`로 주문을 두 번 보내 중복 처리 재현 |
| `curl -X POST -H "x-request-id: ${REQ_ID}" .../api/orders` × 2 | 동일 request_id로 2회 전송 — 둘 다 성공(API 관점 정상) |
| `wait+Ns LLEN order-events` 루프 | 두 event가 drain될 때까지 queue length 관찰 → 0 |
| `psql ... orders where request_id='${REQ_ID}'` | 같은 request_id의 order row가 **2개** 생성 (중복 주문) |
| `psql ... audit_logs where request_id='${REQ_ID}'` | `order_created`/`order_processed` event도 **2세트** 기록 |
| `[note]` | 같은 request_id는 중복을 막지 못함 — idempotency key 필요 |

<details>
<summary>`./04_duplicate_request.sh` 전체 실행 로그</summary>

```text
mac@macui-MacBookPro incident-scenarios % ./04_duplicate_request.sh
[scenario] Duplicate request without idempotency key
[request_id] day2-duplicate-1782374709
... (compose down -> build -> up, order-api /health 200 대기) ...

[1] Send the same request id twice
wait+1s queue_length=2
wait+2s queue_length=2
...
wait+10s queue_length=2
wait+11s queue_length=1
...
wait+22s queue_length=0

[2] Orders with same request_id
 id |  status   |        request_id         |          created_at           |         processed_at
----+-----------+---------------------------+-------------------------------+-------------------------------
  1 | processed | day2-duplicate-1782374709 | 2026-06-25 08:05:25.871364+00 | 2026-06-25 08:05:36.896256+00
  2 | processed | day2-duplicate-1782374709 | 2026-06-25 08:05:25.895985+00 | 2026-06-25 08:05:48.924724+00
(2 rows)

[3] Audit rows with same request_id
 service_name |        request_id         |      event      |     details     |          created_at
--------------+---------------------------+-----------------+-----------------+-------------------------------
 order-api    | day2-duplicate-1782374709 | order_created   | {"order_id": 1} | 2026-06-25 08:05:25.871364+00
 order-api    | day2-duplicate-1782374709 | order_created   | {"order_id": 2} | 2026-06-25 08:05:25.895985+00
 order-worker | day2-duplicate-1782374709 | order_processed | {"order_id": 1} | 2026-06-25 08:05:36.896256+00
 order-worker | day2-duplicate-1782374709 | order_processed | {"order_id": 2} | 2026-06-25 08:05:48.924724+00
(4 rows)

[4] Queue length after duplicate processing
0

[5] Worker logs for duplicate request
order-worker-1  | {"service": "order-worker", "event": "order_event_received", "request_id": "day2-duplicate-1782374709", "order_id": 1, "poll_interval_seconds": 2.0}
order-worker-1  | {"service": "order-worker", "event": "order_processed", "request_id": "day2-duplicate-1782374709", "order_id": 1}
order-worker-1  | {"service": "order-worker", "event": "order_event_received", "request_id": "day2-duplicate-1782374709", "order_id": 2, "poll_interval_seconds": 2.0}
order-worker-1  | {"service": "order-worker", "event": "order_processed", "request_id": "day2-duplicate-1782374709", "order_id": 2}

[note] Same request_id does not prevent duplicates. Real APIs need an idempotency key or unique request boundary.
```

</details>

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| `request_id`와 `idempotency key`의 차이는? | request_id = 추적용(어떤 요청인지 식별), idempotency key = 중복 처리 방지용(같은 key면 한 번만 처리). |
| 같은 `x-request-id`를 보내면 현재 API가 중복을 막는가? | 막지 못한다. 코드가 request_id에 unique constraint를 걸거나 idempotency table을 조회하지 않기 때문. |
| HTTP 요청이 둘 다 200인데 왜 문제인가? | API 관점에선 정상이지만, 사용자는 한 번 주문했다고 생각하는데 order row가 2개 생긴다. |
| 같은 요청이 두 번 들어오는 현실 원인은? | 사용자 더블클릭, client/gateway retry, mobile network 재전송, operator replay 등. |
| retry를 말할 때 항상 같이 말해야 하는 것은? | idempotency. `retry without idempotency = duplicate risk`. |

## notes

### 사고 시나리오 — 같은 요청이 두 번 들어오는 원인

| 원인 | 예 |
|---|---|
| 사용자 더블클릭 | 주문 버튼을 두 번 누름 |
| client retry | timeout 후 같은 요청 재전송 |
| gateway retry | upstream 응답 지연으로 재시도 |
| mobile network | 응답 유실 후 재시도 |
| operator replay | 장애 복구 중 같은 event 재처리 |

#### 왜 모바일이 특히 위험한가

모바일은 유선보다 연결이 자주 끊겨 응답 유실 → 자동 재시도가 빈번하다. 그래서 idempotency를 거의 필수로 신경 써야 한다.

| 상황 | 무슨 일 | 결과 |
|---|---|---|
| 네트워크 전환 (WiFi↔LTE, 신호 끊겼다 재접속) | IP 주소 변경 → 기존 TCP 연결(4-tuple) 깨짐 | in-flight 요청 유실 |
| 커버리지 갭 (지하·터널·엘리베이터) | 패킷 손실 / 연결 끊김 | 응답 못 받음 |
| radio 절전→복귀 (RRC 상태 전환) | 짧은 지연 spike | timeout 유발 |
| Carrier NAT rebinding | 캐리어가 IP/포트 매핑 갱신 | 연결 끊김 |

> 참고: 순수 셀 타워 간 LTE/5G handover는 IP를 유지하도록 설계됨(앵커가 타워가 아니라 게이트웨이 P-GW/UPF). "기지국 바뀔 때마다 IP 변경"은 과장이고, 실제 문제는 위처럼 **연결이 끊기는 순간들**이다.

```text
모바일 연결 끊김
  -> 서버는 처리했는데 응답이 client에 도달 못 함
  -> client는 "실패"로 인식 (실제론 성공)   ← 2교시 ghost pending과 같은 구조
  -> 모바일 HTTP 라이브러리가 자동 재시도
  -> 같은 요청 재전송 -> 중복 주문
```

핵심: **재시도가 많은 환경 = 중복 방어가 더 중요한 환경.** client failure ≠ server failure다.

### 봐야 할 Evidence와 해석

| Evidence | 질문 | 이번 결과 |
|---|---|---|
| `orders` table | 같은 request_id row가 여러 개인가 | 2개 |
| `audit_logs` | event가 중복되는가 | `order_created`/`order_processed` 2세트 |
| worker log | 두 주문 모두 처리됐나 | 모두 처리됨 |
| queue length | 중복 event가 남았나 | drain 후 0 |

| 관찰 | 의미 |
|---|---|
| 같은 request_id의 order row 2개 | 중복 주문 발생 |
| audit event도 2세트 | worker도 각각 처리 |
| HTTP 요청 모두 성공 | API 관점에서는 정상 |
| 사용자 관점 | 한 번 주문했다고 생각했는데 두 번 생성 |

### 핵심 개념

```text
request id      = 추적용
idempotency key = 중복 처리 방지용
```

`x-request-id`가 같아도 현재 API는 중복을 막지 않는다. unique constraint도, idempotency table 조회도 없기 때문.

### 설계 대안

| 방식 | 설명 |
|---|---|
| unique idempotency key | 같은 key로 두 번째 요청이 오면 기존 결과 반환 |
| request log table | 요청 처리 상태를 저장하고 재시도 시 조회 |
| DB unique constraint | 중복되면 안 되는 업무 키에 제약 |
| event id deduplication | worker가 이미 처리한 event id 기록 |
| idempotent update | 같은 event를 여러 번 처리해도 결과가 같게 설계 |

### retry와 연결

retry는 필요하지만 위험하다.

| retry 상황 | 위험 |
|---|---|
| client timeout 후 재시도 | 첫 요청이 실제론 성공했을 수 있음 |
| worker error 후 재시도 | DB update가 이미 일부 수행됐을 수 있음 |
| queue redelivery | 같은 event가 다시 전달될 수 있음 |
| operator 수동 재발행 | 이미 처리된 주문을 다시 처리할 수 있음 |

→ retry를 말할 때는 항상 idempotency를 같이 말해야 한다.

### Kubernetes 연결

| 문제 | Kubernetes 역할 |
|---|---|
| worker pod 죽음 | 재시작 가능 |
| replica 부족 | scale out 가능 |
| 같은 event 중복 처리 | 직접 해결하지 않음 |
| idempotency 보장 | application/database 설계 필요 |

### 운영 리포트 문장

```text
동일 request_id로 주문 생성 요청을 두 번 전송하자 orders table에 두 개의 row가 생성되었다.
audit_logs에도 order_created/order_processed event가 각각 기록되었다.
현재 request_id는 추적에는 사용되지만 중복 방지에는 사용되지 않는다.
중복 주문 방지를 위해 idempotency key 저장소 또는 업무 unique constraint가 필요하다.
```

### 핵심

MSA에서 안정성을 말할 때 retry만 말하면 반쪽이다.

```text
retry without idempotency
  = duplicate risk
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
