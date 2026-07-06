# 7교시: Mesh Traffic 확인

```bash
# 실습 환경 변수
export MESHNS=mesh-demo
export MSANS=mesh-msa-demo
export ISTIONS=istio-system
export MONNS=monitoring
export LAB=cloud-native-devops-2026/week4/day5/labs
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① `kubectl apply -f $LAB/mesh-app/namespace.yaml` (+ deployments/services) | `mesh-demo` 생성, `mesh-frontend`/`mesh-api` 배포 |
| ② `kubectl get ns $MESHNS -o jsonpath='{.metadata.labels.istio-injection}'` | `enabled` — injection namespace 확인 |
| ③ `kubectl -n $MESHNS get pods` | `mesh-api 2/2`, `mesh-frontend 2/2` — **2/2 = 앱+Envoy sidecar 주입됨** |
| ④ `kubectl -n $MESHNS logs deploy/mesh-frontend -c istio-proxy --tail=8` | `"GET /headers" ... outbound\|8080\|\|mesh-api.mesh-demo.svc.cluster.local` — proxy가 본 frontend→api mesh traffic (초기 httpbin 기동 전 503 → 이후 200) |
| ⑤ `kubectl apply -f $LAB/mesh-app/virtualservice-preview.yaml` | `mesh-api-delay-preview` 생성 (fault: 20% 요청 2s 지연) |
| ⑥ proxy 로그 duration 확인 | 대부분 `1~6ms`, ~20%가 `2003~2007ms` — **앱 수정 없이 mesh가 지연 주입** |
| ⑦ `kubectl apply -f $LAB/mesh-msa-app/{namespace,deployments,services}.yaml` | frontend/bff/catalog/inventory/order/payment 6개 배포 |
| ⑧ `kubectl -n $MSANS get pods` | 6개 워크로드 전부 `2/2 Running` |
| ⑨ `kubectl -n $MSANS logs deploy/frontend -c traffic-generator --tail=8` | `bff → catalog/inventory/order`, `order → inventory/payment` 체인 JSON 응답 확인 |
| ⑩ `kubectl apply -f $LAB/mesh-msa-app/virtualservice-order-delay.yaml` | `order-delay-preview` (order로 가는 요청 20% 1s 지연) |
| ⑪ `kubectl -n $MSANS logs deploy/bff -c istio-proxy` → `outbound\|8080\|\|order` duration | 대부분 `2~6ms`, ~20%가 `1005ms` — order 경로만 느려짐 |
| ⑫ 대조: `outbound\|8080\|\|catalog` duration | 항상 `0~2ms` — catalog 경로는 영향 없음 |
| ⑬ **Kiali graph 비어있음** → Prometheus에 istio 메트릭 있나? 임시 curl pod로 `count(istio_requests_total)` 질의 | `result:[]` — **Prometheus가 Istio를 scrape 안 함** (사이드카는 `:15020/stats/prometheus`로 노출 중인데 수집이 안 됨) |
| ⑭ **해결(수업 방식)** `bash $LAB/istio/enable-istio-prometheus-scrape.sh` | `secret/istio-additional-scrape-configs created`, `prometheus ... patched` — Prometheus에 additionalScrapeConfigs로 istio pod scrape job 추가 |
| ⑮ 60초(operator reload) 후 `count(istio_requests_total)` 재질의 | `64` 시계열 수집됨, 새 target `kubernetes-pods-istio` 8개 모두 `up` → `frontend→bff`, `bff→catalog/inventory/order` 라벨 확인 |
| ⑯ Kiali UI: `kubectl -n $ISTIONS port-forward svc/kiali 20001:20001` | `http://localhost:20001` → Namespace `mesh-demo`/`mesh-msa-demo` 선택, 시간범위 Last 5m → graph에 edge/latency 표시 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Pod `2/2`의 의미는? | 앱 container + Envoy sidecar가 함께 있음 = injection 성공. `1/1`이면 sidecar 없음 |
| `1/1`이 나오면 원인은? | namespace label(`istio-injection=enabled`)이 없거나, label 적용 전에 Pod가 이미 생성됨 → 재생성 필요 |
| app log와 istio-proxy log 차이는? | app log=애플리케이션이 남긴 로그, proxy log=proxy가 본 network request(status/duration/upstream) |
| fault injection이 앱 코드를 고쳤나? | 아니오. VirtualService(mesh 설정)로 proxy 레벨에서 지연 주입. 앱은 그대로 |
| order 지연이 catalog엔 영향 없는 이유는? | VirtualService host가 `order`라 order로 가는 경로의 proxy만 지연. 경로별 traffic policy |
| Kiali graph가 비면? | traffic 발생 여부, Prometheus scrape 지연, namespace 선택을 확인. 항상 설치 실패는 아님 |

## notes

### sample app 구조
```text
단순:  mesh-frontend → mesh-api           (frontend가 2초마다 api 호출)
MSA:   frontend → bff → catalog
                      → inventory
                      → order → inventory
                              → payment
```
서비스 2개면 graph가 단순하지만, MSA에서는 한 요청이 여러 서비스로 퍼지고 특정 서비스 지연이 전체 응답에 영향을 준다 — "mesh가 왜 필요한가"를 더 잘 보여준다.

### 배포 순서와 injection
```text
namespace(istio-injection=enabled) → deployments → services
```
injection은 **Pod 생성 시점**에 일어난다. namespace label을 먼저 붙이고 Pod를 만들어야 sidecar가 붙는다. 이미 있던 Pod는 label만으론 안 붙으니 재생성해야 한다.

| READY | 의미 |
|---|---|
| `2/2` | 앱 + Envoy sidecar (정상) |
| `1/1` | 앱만 (injection 안 됨) |

### app log vs istio-proxy log
| 로그 | 의미 |
|---|---|
| app container log | 애플리케이션이 남긴 로그 |
| istio-proxy log | proxy가 본 network request(status code, duration, upstream) |

백엔드 앱이 정상이어도 proxy 로그에서 timeout/reset/routing 문제를 볼 수 있다. Envoy 로그 예시 읽는 법:
```text
"GET /headers HTTP/1.1" 200 - via_upstream ... outbound|8080||mesh-api.mesh-demo.svc.cluster.local
  status=200, 경로=outbound(내가 보낸 요청), upstream=mesh-api Service
```

### fault injection = 앱 밖에서 트래픽 제어
VirtualService로 일부 요청에 지연을 넣는다. 앱 코드는 그대로다.
```yaml
fault:
  delay:
    percentage: { value: 20 }   # 20%만
    fixedDelay: 2s              # 2초 지연
```
- **지연은 호출자(client) 쪽 Envoy에서 주입된다.** 그래서 `bff→order` 지연은 bff의 outbound proxy 로그에서 보인다(order inbound가 아니라).
- host를 `order`로 지정하면 order 경로만 느려지고 catalog 경로는 그대로 → **경로별 traffic policy**를 눈으로 확인.

### 실습에서 관측한 것 (지연 효과)
| 경로 | 지연 주입 | 관측 duration |
|---|---|---|
| mesh-frontend → mesh-api | 20% / 2s | 대부분 1~6ms, ~20%가 2003~2007ms |
| bff → order | 20% / 1s | 대부분 2~6ms, ~20%가 1005ms |
| bff → catalog (대조군) | 없음 | 항상 0~2ms |

### Kiali graph가 비면 — Prometheus scrape 확인 (중요)
Kiali는 스스로 트래픽을 수집하지 않고 **Prometheus의 `istio_requests_total`**을 읽어 graph를 그린다. 트래픽이 흐르는데도 graph가 비면 대부분 Prometheus가 Istio를 scrape하지 않는 경우다.

```text
사이드카(:15020/stats/prometheus) → [Prometheus 수집] → Kiali graph
                                        ↑ 여기가 끊기면 graph 빈다
```

원인: **kube-prometheus-stack의 Prometheus는 `prometheus.io/scrape` 어노테이션을 무시**하고, 별도로 정의한 scrape 대상만 수집한다. Istio 사이드카 pod엔 `prometheus.io/scrape=true`, `prometheus.io/port=15020`, `prometheus.io/path=/stats/prometheus` 어노테이션이 injection 때 자동으로 붙어 있지만, Prometheus가 이 어노테이션을 안 봐서 수집이 안 된 것.

```bash
# 진단: Prometheus에 istio 메트릭 있나 (Prometheus UI 또는 query)
count(istio_requests_total)        # []  이면 수집 안 되는 것
```

해결 방법은 두 가지가 있는데 **하나만** 적용한다(둘 다 하면 중복 수집).

**① 수업 방식 — additionalScrapeConfigs (이번에 적용한 것)**
```bash
bash cloud-native-devops-2026/week4/day5/labs/istio/enable-istio-prometheus-scrape.sh
```
- raw scrape config(`kubernetes-pods-istio` job)를 Secret으로 만들고, Prometheus CR의 `spec.additionalScrapeConfigs`를 patch한다.
- 대상: `mesh-demo`, `mesh-msa-demo` namespace의 `prometheus.io/scrape=true` pod.
- **Prometheus CR 자체를 수정**하는 방식. operator reload에 30~60초 걸림.

**② 대안 — PodMonitor/ServiceMonitor CRD** (`$LAB/istio/podmonitor.yaml`, 파일로 보관)
```bash
kubectl apply -f cloud-native-devops-2026/week4/day5/labs/istio/podmonitor.yaml
```
- prometheus-operator 네이티브 CRD. Prometheus CR을 안 건드리고 monitor 리소스만 추가하면 `podMonitorSelector: {}`가 자동으로 잡는다.
- 추가로 istiod(control plane) ServiceMonitor까지 포함.

| 구분 | ① 스크립트 (수업) | ② PodMonitor (대안) |
|---|---|---|
| 메커니즘 | additionalScrapeConfigs (raw config) | PodMonitor/ServiceMonitor CRD |
| Prometheus CR | patch함(수정) | 안 건드림(리소스 추가) |
| 범위 | mesh-demo, mesh-msa-demo | 모든 namespace istio-proxy |
| istiod 메트릭 | 미포함 | 포함 |

둘 다 같은 어노테이션을 읽어 같은 `istio_requests_total`을 만든다 → 결과(Kiali graph)는 동일. 적용 후 30~60초 지나야 메트릭이 쌓이고, Kiali는 시간범위(Last 5m) 안에 트래픽이 있어야 edge를 그린다.

### Troubleshooting
| 증상 | 확인 |
|---|---|
| Pod가 `1/1` | namespace label, Pod 재생성 |
| Graph가 비어 있음 | traffic 발생 여부, **Prometheus가 istio 메트릭 수집하나(PodMonitor)**, namespace 선택 |
| Kiali 접속 실패 | port-forward service/namespace |
| VirtualService 효과 없음 | host 이름, namespace, CRD 설치 |
| 요청은 되는데 graph 없음 | Prometheus scrape 지연 |
| MSA graph edge 일부만 | 해당 경로 요청이 아직 부족 |

### 한 줄 요약
Mesh traffic 확인은 **Pod 2/2 → app log/proxy log → MSA graph → traffic policy 효과**를 순서대로 보는 것이다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| 배포 직후 proxy 로그에 `503 UH no_healthy_upstream` / `connection termination` | 백엔드(httpbin, MSA 서비스)의 Envoy가 아직 기동 전이라 잠깐 발생. 수 초 뒤 200으로 안정화 |
| order inbound proxy 로그엔 지연이 안 보임 | fault delay는 **호출자(bff) 쪽 Envoy**에서 주입 → bff outbound 로그(`outbound\|8080\|\|order`)에서 1005ms 확인 |
| **트래픽은 흐르는데 Kiali graph가 계속 비어있음** | proxy 로그엔 200 트래픽 있음 → 앱/트래픽 문제 아님. `count(istio_requests_total)`가 `[]` = **Prometheus가 Istio 메트릭을 수집 안 함**. kube-prometheus-stack Prometheus는 사이드카 pod의 `prometheus.io/scrape=true` 어노테이션을 무시함. **수업 방식**: `bash $LAB/istio/enable-istio-prometheus-scrape.sh`(additionalScrapeConfigs로 Prometheus CR patch). 대안: `$LAB/istio/podmonitor.yaml`(PodMonitor CRD). **둘 중 하나만** — 둘 다 하면 중복 수집 |
