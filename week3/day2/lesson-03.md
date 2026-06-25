# 3교시: Readiness Gap과 Transaction Boundary

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| 2교시 script 결과 재사용 | 새 실행 없이 `01_ghost_pending_order.sh` evidence를 설계 관점으로 재분석 |
| `/health` 확인 (D1 기준) | api/order-api 200, db healthy, redis running — 모두 살아 있어도 사고가 났음 |
| transaction boundary 식별 | DB commit 후 `LPUSH redis` 사이가 비-atomic 경계임을 확인 |

### 2교시 결과로 채우는 표

| 항목 | 결과 |
|---|---|
| client response | 503 (실패) |
| DB order exists | 있음 (`pending`) |
| queue event exists | 없음 (`LLEN` 0) |
| audit `order_created` | 있음 |
| audit `order_processed` | 없음 |
| 자동 복구 가능 여부 | 불가 — queue event가 없어 worker가 처리 못 함 |
| 수동 조치 후보 | event 재발행 / compensating job / 상태 확인 후 취소 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| `/health` 200이면 업무 transaction도 안전한가? | 아니다. `/health`는 readiness의 일부만 본다. transaction boundary가 올바른지는 알려주지 않는다. |
| readiness와 consistency의 차이는? | readiness는 "지금 요청 받을 준비가 됐는가", consistency는 "처리 후 내부 상태가 모순 없이 남았는가". |
| 모든 dependency가 살아 있으면 문제없는가? | 아니다. 요청 중간에 한 dependency가 실패하면 경계 설계에 따라 불일치(ghost pending)가 남는다. |
| ghost pending order를 발견하면 바로 삭제해도 되는가? | 안 된다. 사용자 재시도 여부, 결제 여부, event 재발행 가능성, idempotency key, audit 단계를 먼저 확인해야 한다. |
| Kubernetes readinessProbe가 이 문제를 해결하는가? | 아니다. 죽은 container 재시작·ready 아닌 pod 제외는 돕지만 DB/queue atomic·중복 방지·ghost pending 복구는 application 설계 몫이다. |

## notes

### D1과 다른 질문

```text
D1: 모든 dependency가 200/healthy/running 인가?
D2: 모든 dependency가 살아 있을 때만 문제가 없을까?
    한 dependency가 요청 중간에 실패하면 어떤 상태가 남을까?
    health check가 이 불일치를 잡아줄까?
```

### Readiness ≠ 일관성

| 개념 | 질문 |
|---|---|
| readiness | 지금 요청을 받을 준비가 되었는가 |
| consistency | 처리 후 내부 상태가 모순 없이 남았는가 |
| durability | 성공한 상태가 저장되었는가 |
| recoverability | 실패 후 복구/재처리가 가능한가 |

### Transaction Boundary 분석

```text
begin DB work
insert orders
insert order_items
insert audit_logs(order_created)
commit DB
LPUSH redis order-events   <- 여기부터 비-atomic 경계
return 201
```

| 실패 지점 | 남는 상태 | 문제 |
|---|---|---|
| DB insert 전 실패 | 주문 없음 | 단순 |
| DB commit 전 실패 | rollback 가능 | 단순 |
| DB commit 후 Redis 실패 | pending 주문만 남음 | ghost pending |
| Redis 성공 후 response 실패 | client 실패, 내부 처리 진행 | 재시도 시 중복 위험 |
| worker 처리 후 response 없음 | client는 모름, 업무는 완료 | 상태 조회 필요 |

### 설계 대안

| 방식 | 장점 | 단점 |
|---|---|---|
| 현재 방식 | 단순/이해 쉬움 | DB/queue 불일치 가능 |
| DB transaction 안에 outbox 기록 | 상태와 발행 의도를 같이 저장 | publisher 추가 필요 |
| Redis publish 먼저 | queue event는 생김 | DB order row가 없을 수 있음 |
| API 동기 처리 | 완료 기준 단순 | 응답 지연·실패 전파 증가 |
| idempotency key | 재시도 안전성↑ | 저장소·정책 필요 |

### Kubernetes가 해주는 것 / 아닌 것

| 문제 | Kubernetes가 도와주는가 |
|---|---|
| 죽은 container 재시작 | 도움 됨 |
| ready 아닌 pod 제외 | 도움 됨 |
| DB/queue atomic transaction | 직접 해결 안 함 |
| 중복 주문 방지 | application 설계 필요 |
| ghost pending 복구 | job/runbook/application 설계 필요 |

### 핵심

운영 가능한 MSA는 health check만으로 만들어지지 않는다.

```text
readiness        = traffic을 받을 준비
consistency      = 업무 상태가 모순 없이 남는 성질
recoverability   = 깨진 상태를 다시 수습할 수 있는 성질
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
