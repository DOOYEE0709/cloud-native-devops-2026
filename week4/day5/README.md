# Week 4 Day 5 — GitOps와 Service Mesh: Git으로 배포하고 proxy로 traffic을 관찰하기

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Day4 요약 + GitOps 개념 | CI(Actions)와 CD(Argo CD)는 책임이 다름. GitOps=배포 기준을 사람 터미널이 아닌 Git으로. drift=Git과 cluster 불일치. namespace 통신(Service DNS)과 API 권한(RBAC)은 다른 층. Kyverno deny는 sync 실패로 드러남 |
| 2교시 | Argo CD Helm 설치 | server/application-controller/repo-server 역할 구분. kind라 ClusterIP+port-forward. controller SA가 target ns에 `can-i create deployments`=yes여야 sync 가능. redis-secret-init Job timeout은 정상 |
| 3교시 | Argo CD Application 생성 | Application=repoURL+targetRevision+path → destination(server/namespace). `kubernetes.default.svc`=cluster 내부 API server. sync는 통신이 아니라 controller가 API로 object 생성. Synced≠Healthy |
| 4교시 | Drift와 Sync | `scale replicas=2`로 drift 유발 → `OutOfSync`(Deployment만) → 재sync로 replicas 1 복구. Manual/Auto/Self-heal/Prune. `rollout undo`만 하면 새 drift. rollback은 Git 기준 |
| 5교시 | Istio 개념 Preview | Service만으론 latency/error rate/traffic split/mTLS 못 봄. Data plane(Envoy sidecar) vs Control plane(istiod). injection 확인=Pod `2/2`. mesh는 공짜 아님(overhead/debug/learning) |
| 6교시 | Istio/Kiali Helm 설치 | Helm으로 통일(재현성/삭제 용이). base→istiod→gateway 순. gateway=ClusterIP(kind). Kiali는 operator가 CR로 배포, Prometheus metric을 읽어 graph. kiali 처음 `0/1`→Ready 대기 |
| 7교시 | Mesh Traffic 확인 | sidecar `2/2` 배포, istio-proxy access log로 요청 관찰. VirtualService fault로 20%만 지연(mesh-api 2s, order 1s), catalog는 영향 없음(경로별 policy). **Kiali 빈 graph=Prometheus scrape 미설정** |
| 8교시 | 구름 EXP 배움일기 | 하루 evidence 종합. Synced≠Healthy, 1/1 vs 2/2, Kiali 빈 graph 3대 함정. Argo CD/istiod/Kiali는 독립 영역. 다음 심화(app-of-apps, traffic split, mTLS)로 연결 |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 실습 확인 기록·확인 질문·notes·Blocker Log |
| `labs/argocd/` | Argo CD Helm values, Application 템플릿 |
| `labs/gitops-app/` | Argo CD가 sync할 sample app(nginx) |
| `labs/istio/` | Istio/Kiali Helm values, Prometheus scrape 설정 |
| `labs/mesh-app/` | 단순 mesh 데모(frontend→api) + fault injection |
| `labs/mesh-msa-app/` | MSA mesh 데모(frontend→bff→catalog/inventory/order→payment) |

### labs/argocd 구성

| 파일 | 역할 |
|---|---|
| `values.yaml` | Argo CD Helm values (server ClusterIP, insecure, dex/appset/notification off) |
| `application-template.yaml` | `w4d5-gitops-app` Application (repoURL만 본인 것으로 교체, `CreateNamespace=true`) |

### labs/gitops-app 구성 (GitOps로 배포되는 대상)

| 파일 | 역할 |
|---|---|
| `namespace.yaml` | `week4-gitops` namespace |
| `configmap.yaml` | nginx index.html (version v1) |
| `deployment.yaml` | `gitops-web` (nginx:1.27-alpine, replicas 1) |
| `service.yaml` | ClusterIP Service |

### labs/istio 구성

| 파일 | 역할 |
|---|---|
| `base-values.yaml` | istio/base (`defaultRevision: default`) |
| `istiod-values.yaml` | control plane. `meshConfig.accessLogFile: /dev/stdout`로 proxy 로그 관찰 |
| `gateway-values.yaml` | ingress gateway (`type: ClusterIP`, kind용) |
| `kiali-values.yaml` | Kiali CR (anonymous auth, Prometheus URL=`kube-prometheus-stack-prometheus.monitoring:9090`) |
| `enable-istio-prometheus-scrape.sh` | **수업 방식** — additionalScrapeConfigs로 Prometheus가 istio pod를 scrape하게 patch |
| `podmonitor.yaml` | **대안** — PodMonitor/ServiceMonitor CRD로 같은 수집(둘 중 하나만 적용) |

### labs/mesh-app · mesh-msa-app 구성

| 파일 | 역할 |
|---|---|
| `mesh-app/namespace.yaml` | `mesh-demo` (`istio-injection=enabled`) |
| `mesh-app/deployments.yaml` | `mesh-frontend`(2초마다 curl) → `mesh-api`(httpbin) |
| `mesh-app/services.yaml` | mesh-api ClusterIP |
| `mesh-app/virtualservice-preview.yaml` | mesh-api 요청 20%를 2s 지연 |
| `mesh-msa-app/namespace.yaml` | `mesh-msa-demo` (`istio-injection=enabled`) |
| `mesh-msa-app/deployments.yaml` | frontend/bff/catalog/inventory/order/payment |
| `mesh-msa-app/services.yaml` | 각 workload 앞 ClusterIP Service |
| `mesh-msa-app/virtualservice-order-delay.yaml` | order 요청 20%를 1s 지연 |

## 실습 환경

kind cluster `paperclip-w4d2`(node `paperclip-w4d2-control-plane`, v1.36.1), W4D2~D4에 이어서 진행. helm v4.2.2.

- **argocd** namespace: Argo CD `argo-cd-10.1.2` / app `v3.4.4` (server/application-controller/repo-server/redis/appset).
- **week4-gitops** namespace: Argo CD가 Git에서 sync한 `gitops-web`.
- **istio-system**: `istio-base`/`istiod`/`kiali`(operator는 `kiali-operator`), 모두 `1.30.2` / kiali `2.28.0`. **istio-ingress**: gateway(ClusterIP).
- **mesh-demo / mesh-msa-demo**: sidecar 주입된 데모 앱(모두 `2/2`).
- **monitoring**: W4D3 kube-prometheus-stack. Kiali가 이 Prometheus를 읽음.
- GitOps source는 공개 lecture repo(`niceguy61/kdt_devops_lecture_2026_rev2`)의 `week4/day5/labs/gitops-app` 경로 사용.
- ⚠️ **Kiali graph가 비면 Kiali 설치 실패로 단정하지 말 것.** kube-prometheus-stack의 Prometheus는 사이드카 pod의 `prometheus.io/scrape=true` 어노테이션을 무시한다. `enable-istio-prometheus-scrape.sh`(또는 `podmonitor.yaml`)로 수집을 붙여야 `istio_requests_total`이 쌓이고 graph가 그려진다.

## Verified Baseline

```text
kind cluster Ready (paperclip-w4d2)
Argo CD helm release deployed (argo-cd-10.1.2 / v3.4.4)
controller can-i create deployments (week4-gitops) = yes
Application w4d5-gitops-app = Synced / Healthy
gitops-web 1/1 Running (version v1)
drift 재현: scale replicas=2 → OutOfSync(Deployment) → resync → Synced, replicas 1
istio-base / istiod / istio-ingress / kiali-operator 모두 deployed (1.30.2 / 2.28.0)
istiod 1/1, kiali 1/1 Running
mesh-demo: mesh-api 2/2, mesh-frontend 2/2
mesh-msa-demo: frontend/bff/catalog/inventory/order/payment 전부 2/2
fault injection: mesh-api 20% +2s, bff→order 20% +1s, bff→catalog 영향 없음
Prometheus istio scrape 활성화 → count(istio_requests_total)=64, target up → Kiali graph edge 표시
```

## 핵심 한 줄

W4D5는 Kubernetes 운영의 두 축을 연결한 날이다. **Argo CD(GitOps)**는 "배포 기준을 사람의 `kubectl`이 아니라 Git으로 고정"하고, **Istio/Kiali(service mesh)**는 "서비스 간 traffic을 앱 코드 밖 proxy 계층에서 관찰·제어"한다. 둘은 독립적이며, 각각의 검증은 화면이 뜨는 것에서 끝나지 않는다 — Argo CD는 `Synced`와 `Healthy`를 분리해서 보고, Istio는 Pod `2/2`·proxy log·Prometheus 수집·Kiali graph까지 이어서 확인해야 한다.

## cleanup

리소스가 무거우면(Istio/mesh는 local에서 부담) 정리:
```bash
# mesh 앱만
kubectl delete namespace mesh-demo mesh-msa-demo --ignore-not-found

# Istio/Kiali까지
helm uninstall kiali-operator -n kiali-operator
helm uninstall istio-ingress -n istio-ingress
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system
kubectl -n monitoring delete secret istio-additional-scrape-configs --ignore-not-found

# Argo CD까지
kubectl -n argocd delete application w4d5-gitops-app
kubectl delete namespace week4-gitops --ignore-not-found
helm uninstall argocd -n argocd
```
유지 시 `helm list -A`, `kubectl get application -A`, `kubectl get ns` 결과를 기록한다.

## Official References

| Topic | Reference |
|---|---|
| Argo CD | https://argo-cd.readthedocs.io/ |
| Argo CD Application | https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/ |
| Istio (Helm install) | https://istio.io/latest/docs/setup/install/helm/ |
| Istio Traffic Management | https://istio.io/latest/docs/tasks/traffic-management/ |
| Kiali | https://kiali.io/docs/ |
| Prometheus Operator (PodMonitor) | https://prometheus-operator.dev/docs/developer/getting-started/ |
