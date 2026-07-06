# 5교시: Istio 개념 Preview

```bash
# 실습 환경 변수
export NS=week4-gitops
export MESHNS=mesh-demo
export LAB=cloud-native-devops-2026/week4/day5/labs
```

## 실습 확인 기록

> 5교시는 개념 preview. Istio 실제 설치는 6교시라, 여기서는 "mesh 적용 전 baseline"을 눈으로 확인한다.

| 명령/확인 | 결과 |
|---|---|
| ① `kubectl -n $NS get pod` | `gitops-web-... 1/1 Running` — READY가 `1/1` = 앱 container만, sidecar 없음 |
| ② `kubectl get ns istio-system` | `NotFound` — 아직 control plane(istiod) 없음 → 6교시에서 설치 |
| ③ `ls $LAB/mesh-app` | `namespace.yaml`, `deployments.yaml`, `services.yaml`, `virtualservice-preview.yaml` (6·7교시에서 사용) |
| ④ (개념) sidecar injection 예: `kubectl label namespace $MESHNS istio-injection=enabled` 후 Pod가 `2/2`면 앱+Envoy | 실제 `2/2`는 Istio 설치 후 6교시에서 확인 예정 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Kubernetes Service만으로 보기 어려운 것은? | latency 분포, service-to-service error rate, traffic split, fault injection, mTLS 상태 |
| 서비스 메시란? | 서비스 간 통신을 관찰·제어하는 인프라 계층. 앱 코드 바깥의 proxy에서 metric/routing/retry/timeout/mTLS 처리 |
| Data plane vs Control plane? | Data plane=Envoy sidecar(실제 요청 처리), Control plane=istiod(Envoy 설정 배포/discovery/cert 관리) |
| istiod가 요청을 직접 처리하는가? | 아니오. 요청은 각 Pod 옆 Envoy proxy를 지남. istiod는 설정만 배포 |
| sidecar injection 확인 기준은? | Pod READY 컬럼. `1/1`=앱만, `2/2`=앱+Envoy sidecar |
| mesh가 항상 좋은가? | 아니오. resource overhead, debug 복잡도, learning curve, upgrade 부담. 단순·소규모 팀엔 과할 수 있음 |

## notes

### Kubernetes Service만으로 부족한 지점
Service는 Pod 집합에 안정적 이름/가상 IP를 준다. 하지만 "연결된다"만으로 운영이 안 된다.

| 운영 질문 | Service만으로 보기 어려운 것 |
|---|---|
| 어떤 서비스가 느린가 | 요청 latency 분포 |
| 어느 경로에서 실패하는가 | service-to-service error rate |
| 일부만 새 버전으로 보낼 수 있나 | traffic split |
| 장애를 일부러 재현할 수 있나 | delay/fault injection |
| 서비스 간 암호화가 되나 | mTLS 상태 |

### 서비스 메시란
서비스 간 통신을 관찰·제어하는 인프라 계층. 앱 코드 바깥의 proxy가 metric/log/routing/retry/timeout/mTLS를 처리한다.

```text
app container → local proxy → network → local proxy → app container
```

### Istio의 두 평면 (꼭 분리)
| 구분 | 구성요소 | 역할 |
|---|---|---|
| Data plane | Envoy sidecar | 실제 요청을 받고 보내는 proxy |
| Control plane | istiod | Envoy 설정 배포, service discovery, cert 관리 |

```text
istiod는 요청을 직접 처리하지 않는다.
요청은 각 Pod 옆의 Envoy proxy를 지난다.
```

### Sidecar injection 확인 기준
namespace에 injection을 켜면 Pod 생성 시 Envoy container가 함께 붙는다. Pod READY 컬럼으로 판별:

```text
1/1  → 앱 container만
2/2  → 앱 container + Envoy sidecar
```

오늘 baseline: `week4-gitops`의 gitops-web Pod가 `1/1`(sidecar 없음). 6교시에서 Istio 설치 → injection → `2/2`로 바뀌는 걸 대조한다.

### Mesh가 주는 것
| 기능 | 수업에서 보는 방식 |
|---|---|
| Traffic graph | Kiali graph |
| Request metric | Prometheus metric |
| Access log | `istio-proxy` container logs |
| Fault injection | VirtualService delay |
| Policy preview | mTLS/RBAC 개념 소개 |

### Mesh가 항상 좋은 건 아니다
| 비용 | 설명 |
|---|---|
| Resource overhead | Pod마다 proxy 추가 → CPU/Memory 증가 |
| Debug 복잡도 | 앱 문제인지 proxy/routing 문제인지 분리 필요 |
| Learning curve | Gateway, VirtualService, DestinationRule 학습 |
| Upgrade 부담 | control plane과 sidecar 버전 관리 |

단순·소규모 팀엔 과할 수 있고, 서비스 수가 늘고 장애 분석·traffic 제어가 중요해지면 가치가 커진다.

### Compose → K8s Service → Mesh
```text
Compose:  frontend → backend → db  (service name)
K8s:      frontend → backend.default.svc.cluster.local
Istio:    frontend app → frontend envoy → backend envoy → backend app
```
네트워크 이해가 Service 이해로, Service 이해가 mesh 이해로 이어진다.

### istiod vs Kiali (헷갈리기 쉬움)
둘 다 Istio 쪽이지만 역할이 완전히 다르다.

| | istiod | Kiali |
|---|---|---|
| 분류 | Control plane (제어) | 관측 도구 (Observability) |
| 하는 일 | proxy에 설정 배포, mesh 운영 | 트래픽을 그래프로 시각화 |
| 없으면? | mesh 자체가 동작 안 함 | mesh는 돌지만 눈으로 못 봄 |
| 데이터 출처 | 직접 관리 | Prometheus에서 읽음 |

- **istiod = mesh의 두뇌.** 각 Pod 옆 Envoy sidecar에게 라우팅/재시도/mTLS 설정을 내려준다. 실제 요청을 직접 처리하진 않는다.
- **Kiali = 관측 대시보드.** 스스로 수집하지 않고 Prometheus metric을 읽어 A→B→C 트래픽 그래프를 그린다.
- 비유: istiod = 교통 관제실(동선 제어), Kiali = CCTV 상황판(보기만).

### 오늘 배운 3가지 컴포넌트 위치
같은 날 다뤘지만 서로 독립적인 영역이다.

| 도구 | 영역 | 한 줄 |
|---|---|---|
| **Argo CD** | 배포 (CD/GitOps) | Git에 적힌 대로 클러스터를 맞춰주는 배포 컨트롤러 |
| **istiod** | 서비스 메시 (제어) | Pod 옆 proxy에 트래픽 설정을 배포하는 mesh 두뇌 |
| **Kiali** | 관측 (대시보드) | mesh 트래픽 흐름을 그래프로 보여주는 UI |

- 비유: Argo CD = 설계도(Git)대로 계속 맞춰 짓는 **시공 감독**, istiod = 동선 통제 **관제실**, Kiali = **CCTV 상황판**.
- 서로 의존 없음 — Argo CD 없이도 mesh는 돌고, mesh 없이도 Argo CD 배포는 된다.

### 한 줄 요약
Istio는 서비스 간 요청 경로에 **proxy를 넣어 traffic을 관찰·제어**하는 서비스 메시다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
