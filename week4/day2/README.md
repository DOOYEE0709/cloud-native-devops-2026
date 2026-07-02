# Week 4 Day 2 — Kubernetes Networking과 Gateway API로 traffic 다루기

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Day1 요약 + Kubernetes Networking 다시 잡기 | traffic 장애는 Gateway→HTTPRoute→Service→Endpoint→Pod readiness 순서로 좁힘. "Service 있다" ≠ "갈 endpoint 있다" |
| 2교시 | MSA 앱 내부 통신 | 내부는 Service DNS로, port(client)/targetPort(Pod) 구분. db는 ClusterIP 내부 backend로 숨김 |
| 3교시 | Gateway API와 Envoy Gateway 설치 | GatewayClass/Gateway/HTTPRoute로 의도 선언 → Envoy Gateway controller가 Envoy data plane으로 반영 |
| 4교시 | HTTPRoute 작성 | Gateway=받을 문(listener), HTTPRoute=host/path로 backend 고르는 routing 계약. Host header 맞아야 라우팅 |
| 5교시 | Gateway/HTTPRoute 장애 분석 | 404(라우팅)/503(backend)/refused(접근) 구분, Accepted·ResolvedRefs·Programmed condition으로 층별 진단 |
| 6교시 | NetworkPolicy와 Cilium/Hubble Preview | namespace 자동격리 아님. label 기반 허용선(ingress/egress), default deny 위에 필요만 개방. kindnet v20260528은 실제 강제 |
| 7교시 | Rollout과 External Traffic | 외부→Gateway→HTTPRoute→Service→Pod. kind는 LB 없어 PROGRAMMED=False(주소만 미할당)라도 port-forward로 접근. RollingUpdate 1개씩 교체, undo로 rollback |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-07.md` | 교시별 핵심 정리·실습 확인 기록·확인 질문·notes·Blocker Log |
| `labs/traffic-routing/` | MSA 3-tier(frontend/api/postgres) Deployment·Service·ConfigMap·Secret, Gateway·HTTPRoute, NetworkPolicy, rollout용 v2, 고장 재현 manifest |
| `labs/envoy-gateway/` | Envoy Gateway 설치용 GatewayClass·Helm values |

### labs/traffic-routing 주요 manifest

| 파일 | 역할 |
|---|---|
| `namespace.yaml` | week4 namespace |
| `frontend-deployment.yaml` / `frontend-configmap.yaml` | 웹 tier(:80) + 런타임 config |
| `api-deployment.yaml` / `api-deployment-v2.yaml` | api tier(:8080) v1/v2 (rollout 실습) |
| `db-deployment.yaml` / `db-secret.yaml` | postgres tier(:5432) + Secret |
| `services.yaml` | api/frontend/postgres ClusterIP |
| `gateway.yaml` / `httproute.yaml` | Gateway(listener paperclip.local:80) + host/path 라우팅 |
| `networkpolicy-preview.yaml` | default-deny + 역할별 allow(8종): frontend↔api, api↔db, DNS egress, envoy gateway 진입 |
| `broken-httproute-wrong-parent.yaml` / `broken-httproute-wrong-port.yaml` / `broken-service-wrong-selector.yaml` | 5교시 장애 재현(잘못된 parentRef/port/selector) |

## 실습 환경

kind cluster `paperclip-w4d2`(node `paperclip-w4d2-control-plane`), namespace `week4`.
add-on으로 **Envoy Gateway**(`envoy-gateway-system`)를 3교시에서 설치한다. CNI는 kindnet `v20260528`(NetworkPolicy enforcement 포함).

- 외부 접근은 kind에 LoadBalancer가 없어 Envoy data plane Service를 **port-forward**하는 방식을 기본으로 둔다(3교시에서 켜고 이후 교시 내내 유지):
  ```bash
  kubectl -n envoy-gateway-system port-forward svc/envoy-week4-paperclip-gateway-184e87dc 8080:80
  # 다른 터미널
  curl -H "Host: paperclip.local" http://localhost:8080/api
  ```

## 핵심 한 줄

Kubernetes traffic은 **선언한 것**(Gateway/HTTPRoute/Service/NetworkPolicy)과 **실제 도달**(Endpoint/readiness/CNI enforcement)이 다를 수 있다. 그래서 장애는 층을 나눠(404 라우팅 / 503 backend / refused 접근) condition과 endpoint로 좁히고, 접근은 허용선(NetworkPolicy)으로 막으며, 배포는 RollingUpdate로 무중단 교체하고 undo로 되돌린다.

## 다음 연결

W4D2에서 세운 외부 진입점(Gateway)·내부 허용선(NetworkPolicy)·무중단 배포(rollout)는 이후 관찰/운영 계층으로 확장된다. Gateway/HTTPRoute traffic은 W4D5 Istio(mesh 계층), NetworkPolicy는 Cilium/Hubble(CNI·eBPF 계층)로 이어지고, rollout의 readiness→endpoint 반영은 W4D3 metric/HPA 관찰과 연결된다.
