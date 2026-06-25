# 8교시: 운영 플랫폼 연결과 구름 EXP 배움일기

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| Day2 4개 사고 evidence 종합 | ghost pending / backlog / poison / duplicate를 K8s·application 책임으로 분류 |
| "K8s가 해결" vs "application이 해결" 구분 | scheduling/restart/scaling은 K8s, consistency/idempotency는 application |
| 구름 EXP 배움일기 작성 | 감상이 아니라 사고 evidence 중심으로 작성 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Kubernetes가 해결하는 문제 범위는? | scheduling/restart/discovery/scaling 같은 플랫폼 primitive. 죽은 pod 재시작, replica 유지, readiness 제외 등. |
| K8s가 해결하지 못하는 것은? | transaction boundary(DB commit 후 publish 실패), 중복 주문, poison message 유실, 업무 reconciliation, 결제/주문 보상 — 모두 application/domain 설계. |
| readinessProbe로 ghost pending을 막을 수 있나? | 아니다. probe는 준비 안 된 pod로 traffic을 안 보낼 뿐, DB/queue 불일치는 outbox/idempotency로 application이 해결. |
| 배움일기는 어떻게 써야 하나? | 감상이 아니라 선택한 사고의 재현 명령 → client symptom → internal evidence → mismatch → 조치 → 설계 보완 순으로. |
| Day2의 한 줄 결론은? | D1은 정상 경로 실행, D2는 정상 경로가 깨질 때 내부 상태가 어긋나는 것을 관찰, K8s는 그중 일부를 플랫폼에서 다루기 시작. |

## notes

### 오늘 본 사고와 연결 개념

| 사고 | 운영 플랫폼이 도와주는 것 | application이 해결해야 하는 것 |
|---|---|---|
| Ghost pending order | job 실행, metrics, alert | outbox, 보상 transaction |
| Worker backlog | replica scale, HPA | idempotent worker, 처리량 설계 |
| Poison message | logs/metrics alert | DLQ, schema validation, retry policy |
| Duplicate request | traffic routing은 가능 | idempotency key, unique constraint |
| Readiness gap | readinessProbe | business consistency |

```text
Kubernetes solves   scheduling / restart / discovery / scaling primitives.
Application design solves   consistency / idempotency / business recovery.
```

### 사고별 Kubernetes 연결

| Day 2 evidence | Kubernetes/운영 개념 |
|---|---|
| worker가 멈춤 | Deployment, ReplicaSet |
| queue backlog 증가 | metrics, HPA, alert |
| ready 아닌 service | readinessProbe |
| process hang | livenessProbe |
| service name 통신 | Service DNS |
| 환경별 설정 | ConfigMap, Secret |
| 사고 로그 분산 | centralized logging, tracing |
| audit timeline | observability + business audit |

> 참고(네트워크): service 통신·network 격리는 결국 subnet(CIDR) 문제로 이어진다. Docker `msa-net`, K8s Pod/Service CIDR, 클라우드 VPC subnet 대역을 시각적으로 계산해보는 도구 — <https://cidr.xyz/> (IP/CIDR를 넣으면 netmask·network·broadcast·host 범위를 옥텟별로 색칠해 보여줌).

### 하지만 K8s만으로 안 되는 것

| 문제 | 이유 |
|---|---|
| DB commit 후 Redis publish 실패 | transaction boundary 문제 |
| 중복 주문 | idempotency 설계 필요 |
| poison message 유실 | DLQ/retry metadata 필요 |
| 업무 상태 reconciliation | application/job 설계 필요 |
| 결제/주문 보상 처리 | domain policy 필요 |

→ 이 구분을 못 하면 Kubernetes를 배우고도 운영 사고를 제대로 해결하지 못한다.

### Observability 3대 기둥 — logs / traces / metrics

흔히 "로그 중앙화 → tracing → 차트 → 사용자 급감 감지"로 뭉뚱그리는데, 셋은 역할이 다르다. 특히 **시계열 차트·급감 감지는 tracing이 아니라 metrics**다.

| 기둥 | 답하는 질문 | 대표 도구 | 형태 |
|---|---|---|---|
| Logs (중앙화) | "무슨 일이 있었나" (개별 event 원문) | ELK, Loki | 텍스트/JSON event |
| Traces | "한 요청이 어느 서비스에서 얼마나 걸렸나/어디서 실패했나" | Jaeger, Tempo | 요청 1건의 경로(span) |
| Metrics | "전체가 시간에 따라 어떻게 변하나" | Prometheus + Grafana | 숫자 시계열 |

```text
로그 중앙화  -> 흩어진 서비스 로그를 한 곳에서 검색 (무슨 일?)
tracing      -> 요청 하나를 서비스 넘나들며 추적 (어디서 느렸나/깨졌나)
metrics      -> 시계열 데이터 + 차트 + "사용자 급감" 감지   ← 이게 핵심
```

#### Day2 사고로 연결

| 사고 / 관찰 | 어느 기둥이 잡아주나 |
|---|---|
| 주문 요청 급감 / queue backlog 증가 | metrics (시계열로 추세·alert) |
| "이 주문(request_id)이 어디서 멈췄나" | traces (서비스 경로 추적) |
| `worker_error` 원문, audit event | logs (중앙화로 원인 조사) |

- 4교시의 "순간값이 아니라 지속 시간·추세로 판단" = metrics 시계열이 필요한 이유.
- 5교시 poison message에서 request_id가 가짜였던 것 = tracing이 제대로 되려면 요청마다 trace_id가 끝까지 전파돼야 한다는 것과 연결.

### 다음 수업으로 넘길 질문

| 질문 | 다음 연결 |
|---|---|
| worker replica를 늘리면 backlog가 줄어드는가 | Deployment scale |
| readinessProbe는 어디까지 확인해야 하는가 | probe 설계 |
| Secret과 ConfigMap은 사고를 줄이는가 | 설정 관리 |
| logs만으로 충분한가 | metrics/tracing |
| Kubernetes Job으로 ghost pending을 보정할 수 있나 | batch/reconciliation |

### 핵심

```text
D1: MSA 정상 경로를 실행했다.
D2: 정상 경로가 깨질 때 내부 상태가 어떻게 어긋나는지 봤다.
K8s: 이 운영 문제 중 일부를 플랫폼 수준에서 다루기 시작한다.
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
