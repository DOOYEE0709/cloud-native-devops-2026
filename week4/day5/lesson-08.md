# 8교시: 구름 EXP 배움일기

```bash
# 실습 환경 변수 (오늘 전체)
export ARGONS=argocd
export GITOPSNS=week4-gitops
export ISTIONS=istio-system
export MESHNS=mesh-demo
export MSANS=mesh-msa-demo
```

## 실습 확인 기록

> 오늘(W4D5) 실제로 세운 것들의 최종 상태 evidence.

| 명령/확인 | 결과 |
|---|---|
| ① `helm list -n $ARGONS` | `argocd` `argo-cd-10.1.2` deployed (Argo CD) |
| ② `kubectl -n $ARGONS get application w4d5-gitops-app` | `Synced / Healthy` |
| ③ `kubectl -n $GITOPSNS get deploy,svc,pod` | `gitops-web 1/1`, `svc/gitops-web ClusterIP 80`, `pod Running` (GitOps로 배포됨) |
| ④ (4교시 재현) `kubectl -n $GITOPSNS scale deploy/gitops-web --replicas=2` → refresh | drift → `OutOfSync` (Deployment만) → 재sync → `Synced`, replicas 1 복구 |
| ⑤ `helm list -A \| grep -iE "istio\|kiali"` | `istio-base 1.30.2`, `istiod 1.30.2`, `istio-ingress 1.30.2`, `kiali-operator 2.28.0` |
| ⑥ `kubectl -n $MESHNS get pods` | `mesh-api 2/2`, `mesh-frontend 2/2` — sidecar 주입 |
| ⑦ `kubectl -n $MSANS get pods` | frontend/bff/catalog/inventory/order/payment 6개 전부 `2/2` |
| ⑧ `kubectl -n $MESHNS get virtualservice` + `$MSANS` | `mesh-api-delay-preview`, `order-delay-preview` (fault injection) |
| ⑨ proxy 로그 지연 관측 | mesh-api 20% 2s, bff→order 20% 1s, bff→catalog 영향 없음 |
| ⑩ Kiali graph | `count(istio_requests_total)` 64 시계열, `kubernetes-pods-istio` target `up` → graph에 edge 표시 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 오늘 배운 두 축은? | ① GitOps 배포(Argo CD) ② 서비스 메시 관찰/제어(Istio/Kiali) — 서로 독립 |
| Argo CD가 남긴 evidence는? | Helm release, Application `Synced/Healthy`, drift 시 `OutOfSync` + Diff |
| Istio가 남긴 evidence는? | Pod `2/2`(sidecar), istio-proxy access log, Kiali graph, VirtualService 지연 효과 |
| Kiali graph가 비면 무엇부터? | traffic 발생 → Prometheus 수집(scrape) → namespace/시간범위 선택 순 |
| 다음 심화로 이어질 질문은? | app-of-apps/sync wave, traffic split, mTLS, authorization policy, Kyverno와 GitOps 공존 |

## notes

### 오늘 배운 내용 요약
| 교시 | 핵심 질문 | 핵심 산출물 |
|---|---|---|
| 1 | GitOps가 왜 필요한가 | CI/CD/GitOps 역할 구분 |
| 2 | Argo CD는 어떻게 설치하는가 | Helm release, UI 접속, controller 권한 |
| 3 | Application은 무엇을 연결하는가 | repoURL/path/destination → sync |
| 4 | drift는 어떻게 발견/복구하는가 | OutOfSync, sync, rollback 기준 |
| 5 | service mesh가 왜 필요한가 | data plane/control plane 구분 |
| 6 | Istio/Kiali를 어떻게 설치하는가 | Helm release, Prometheus 연결 |
| 7 | mesh traffic은 어디서 보는가 | Kiali graph, proxy log, fault injection |

### 오늘의 운영 관점
| 주제 | 운영 질문 |
|---|---|
| GitOps | 운영 상태의 기준은 Git인가, cluster인가 |
| Argo CD | sync 실패가 배포 문제인가, policy 문제인가 |
| Drift | 임시 변경을 Git에 반영할 것인가, 되돌릴 것인가 |
| Istio | proxy 계층을 추가할 만큼 traffic 관찰/제어가 필요한가 |
| Kiali | graph가 비면 traffic·Prometheus·namespace 중 무엇부터 볼 것인가 |

### 오늘 만난 핵심 함정 3가지 (직접 겪음)
| 함정 | 정리 |
|---|---|
| Synced ≠ Healthy | Git과 일치해도 Pod가 죽으면 사용자 입장에선 정상 아님 |
| `1/1` vs `2/2` | `2/2`가 sidecar 주입 성공. injection은 Pod 생성 시점에 일어남 |
| Kiali 빈 graph | 설치 실패 아님 — kube-prometheus-stack이 사이드카 `prometheus.io/scrape` 어노테이션을 무시 → additionalScrapeConfigs 또는 PodMonitor로 수집 붙여야 함 |

### 오늘 배운 3가지 컴포넌트 (한 줄 정의)
| 개념 | 한 줄 정의 |
|---|---|
| GitOps | Git을 운영 상태의 기준으로 삼는 배포 방식 |
| Argo CD | Git desired state를 cluster에 sync하는 controller |
| Drift | Git과 cluster 상태가 달라진 상태(OutOfSync) |
| Istio | service-to-service traffic을 proxy로 관찰/제어하는 mesh |
| Kiali | Istio mesh traffic을 graph로 보여주는 UI (Prometheus 읽음) |

### 다음 Kubernetes 여정 연결
| 다음 주제 | 이어지는 질문 |
|---|---|
| Helm 심화 | values와 chart를 팀 표준으로 관리할 수 있는가 |
| Argo CD 심화 | app-of-apps, sync wave, promotion 전략 |
| Istio 심화 | traffic split, mTLS, authorization policy |
| Observability | metric/log/trace를 하나의 장애 분석 흐름으로 |
| Policy | Kyverno와 GitOps를 충돌 없이 운영 |

### 한 줄 요약
오늘은 Kubernetes 운영을 **Git 기준으로 배포(Argo CD)**하고 **service mesh 기준으로 traffic을 관찰(Istio/Kiali)**하는 첫 연결점을 만든 날이다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| (종합) 오늘 겪은 blocker 3건 | ② redis-secret-init Job timeout(정상), ③ Application status 지연 표시(20~30초 후 Synced), ⑦ Kiali 빈 graph(Prometheus scrape 미설정) — 각 교시 Blocker Log 참고 |
