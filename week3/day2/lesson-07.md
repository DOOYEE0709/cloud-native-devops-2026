# 7교시: Incident Timeline과 현실형 Runbook

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `cd week3/day2/labs/incident-scenarios` 후 `./01_ghost_pending_order.sh` 재실행 | 한 사고를 골라 timeline 작성용 evidence 재수집 |
| client status / DB row / queue / worker / audit를 시간순으로 묶음 | 단일 리포트가 아니라 사고 timeline으로 정리 |
| 복구 명령보다 복구 "기준"을 먼저 정의 | "뭘 재시작할까"가 아니라 "어떤 상태를 정상으로 볼까" 먼저 |

### 작성 예시 — Ghost pending order timeline

```text
T1 client가 주문 요청을 보냈다.
T2 order-api가 DB에 pending 주문을 만들었다.
T3 Redis publish가 실패했다.
T4 client는 503을 받았다.
T5 queue에는 event가 없다.
T6 audit에는 order_created만 있고 order_processed는 없다.
T7 이 주문은 자동 처리되지 않는 ghost pending order다.
```

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 왜 한 줄 리포트가 아니라 timeline인가? | MSA 사고는 여러 service에 걸쳐 단계별로 진행돼 한 줄("Redis 장애로 주문 안 됨")로는 원인·영향·복구 판단이 안 된다. |
| timeline에 묶어야 할 evidence는? | client / API / DB / queue / worker / audit를 시간 순서로 + 마지막에 Decision(조치). |
| 좋은 runbook과 나쁜 runbook의 차이는? | 나쁜 건 명령 모음(`restart`, `logs`). 좋은 건 확인→판단→다음 행동이 있는 의사결정 절차. |
| 복구에서 명령보다 먼저 정해야 할 것은? | 복구 기준(recovery criteria). `recovery command < recovery evidence < recovery criteria`. |
| 사고 유형은 무엇으로 구분하나? | DB row 상태, queue length, worker log(processed/error/없음), audit 단계의 조합으로 구분. |

## notes

### 왜 timeline인가

```text
나쁜 리포트:  Redis 장애로 주문이 안 됐습니다.

좋은 timeline: client 요청 -> DB pending 생성 -> Redis publish 실패
            -> client 503 -> queue 비어 있음 -> audit order_created만
            -> ghost pending order로 결론
```

### Timeline Template

| 단계 | Evidence | 해석 |
|---|---|---|
| Client | HTTP status/body | 사용자가 본 결과 |
| API | order-api log 또는 audit | API가 어느 단계까지 수행했나 |
| DB | `orders` row | 업무 상태가 남았나 |
| Queue | Redis `LLEN` | 처리 event가 존재하나 |
| Worker | worker log | event를 소비/실패했나 |
| Audit | `audit_logs` | 업무 event가 어느 단계까지 기록됐나 |
| Decision | 조치 | 재처리/취소/대기/확대 판단 |

### 트러블슈팅의 "깊이" — 어디까지 봤는가 (STAR 기법)

아키텍처를 보는 것 자체보다, **어디까지 파고들어 원인을 짚었는가**가 평가된다. 같은 사고를 어떻게 적느냐가 곧 실력 차이다.

```text
나쁨: "레디스가 다운됐길래 다시 올렸더니 됐습니다."
      -> 원인 모름, 재발 시 또 똑같이 당함, 운(luck)으로 복구

좋음: "레디스가 OOM(메모리 한계)으로 죽은 것 같아서 maxmemory 정책을
      이렇게 바꾸고 재기동했더니 정상화됐습니다."
      -> 가설 -> 근거 -> 조치 -> 결과가 드러남
```

이걸 정리하는 틀이 **STAR**다. 사고 리포트·면접·프로젝트 회고에서 그대로 쓰인다.

| STAR | 의미 | 이 수업의 Timeline과 매핑 |
|---|---|---|
| **S**ituation | 어떤 상황/사고였나 | Client~Audit evidence (무슨 일이 있었나) |
| **T**ask | 무엇을 해결해야 했나 | 정상으로 봐야 할 상태(복구 기준) 정의 |
| **A**ction | 어떤 가설로 무엇을 했나 | Decision + 조치 (왜 그렇게 판단했는지 근거 포함) |
| **R**esult | 결과가 어땠나 | recovery evidence (상태 정상화 확인) |

핵심: "재시작하니 됐다"는 **A·R만 있고 S·T(원인 가설)가 빠진** 반쪽 보고다. Timeline이 곧 STAR의 S(근거)를 채워주는 도구다. → 나중에 프로젝트/실무 incident report에서 이 형식으로 쓴다.

### 사고 유형별 Decision Table

| 사고 | 판단 기준 | 우선 조치 |
|---|---|---|
| Ghost pending order | DB pending row 있음, queue event 없음 | 재발행/취소 정책 확인 |
| Worker backlog | queue length 증가, pending 다수 | worker 복구 또는 scale out |
| Poison message | worker_error, audit 없음 | DLQ 격리, payload 검증 |
| Duplicate request | 같은 request id row 다수 | idempotency 설계 필요 |
| DB down | 여러 API readiness 실패 | DB 복구 후 dependent service 확인 |

### Runbook은 명령 모음이 아니다

| 순서 | 확인 | 판단 | 다음 행동 |
|---|---|---|---|
| 1 | client status | 실패/성공 여부 | 내부 상태와 비교 |
| 2 | DB order row | pending/processed/duplicate | queue 또는 worker 확인 |
| 3 | Redis queue | event 있음/없음 | worker 복구 또는 재발행 판단 |
| 4 | worker log | processed/error/없음 | poison/backlog/down 구분 |
| 5 | audit log | created/processed 여부 | 업무 단계 확정 |
| 6 | recovery evidence | 상태 정상화 여부 | incident close |

### 운영 리포트 표 (Ghost pending 예시)

| 항목 | 작성 내용 |
|---|---|
| Incident title | Ghost pending order during Redis outage |
| Scenario script | `01_ghost_pending_order.sh` |
| Request id / prefix | `day2-ghost-pending-...` |
| User-visible symptom | 주문 실패(503) 응답 |
| Internal state mismatch | client 실패인데 DB엔 pending row 존재 |
| Queue evidence | `LLEN order-events` = 0 (event 없음) |
| DB evidence | `orders.status` = pending |
| Worker evidence | 처리 대상 event 없음 → 처리 안 됨 |
| Audit evidence | `order_created`만, `order_processed` 없음 |
| Immediate action | pending 주문 식별 후 재발행/취소 정책 적용 |
| Long-term fix | outbox pattern + idempotency key + reconciliation |

### 복구 기준 예시

| 사고 | 복구 기준 |
|---|---|
| Ghost pending order | pending 주문이 재발행/취소/처리 중 하나로 정리됨 |
| Backlog | queue length 정상 범위로 감소 + pending이 processed로 전환 |
| Poison message | 실패 message가 DLQ 또는 조사 대상으로 격리됨 |
| Duplicate request | 중복 row 영향이 정리되고 idempotency 보완 계획 수립 |

### 핵심

현실적인 장애 대응은 "뭘 재시작할까"보다 "어떤 상태를 정상으로 볼까"를 먼저 정하는 일이다.

```text
recovery command
  < recovery evidence
  < recovery criteria
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
