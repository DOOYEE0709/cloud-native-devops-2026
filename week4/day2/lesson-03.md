# 3교시: Gateway API와 Envoy Gateway 설치

## 핵심 정리

### Docker reverse proxy → Kubernetes Gateway
```text
[Docker]  browser → nginx reverse proxy container → frontend/api
[K8s]     API object(GatewayClass/Gateway/HTTPRoute) + controller(Envoy Gateway) + data plane(Envoy proxy)
```
- ⭐ 변화: **"proxy 설정 파일을 직접 관리"** → **"routing 의도를 API object로 선언하면 controller가 proxy를 맞춤"**.

### Gateway API 구성요소 — 역할 분리
| 리소스 | 누가 관리 | 의미 |
|---|---|---|
| **GatewayClass** | platform/infra | 어떤 controller가 Gateway를 처리할지 (≈ IngressClass) |
| **Gateway** | platform | listener·port·protocol·route attach 범위 |
| **HTTPRoute** | app owner | host/path/header 기반 routing (4교시) |
| Service | app owner | backend 안정 진입점 |
| EndpointSlice | K8s | Ready Pod IP 목록 |

- ⭐ Ingress는 **하나의 object에 다 몰림** → Gateway API는 역할을 잘게 나눠 **platform owner와 app owner 책임 분리**.

### controller vs data plane — 반드시 구분
```text
Envoy Gateway controller = API object 감시/반영 (제어)
Envoy proxy data plane   = 실제 HTTP traffic 처리 (전달)
```

### Helm 설치 — OCI registry (repo add 아님!) + GatewayClass 직접 apply
```bash
helm upgrade --install envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --version v1.8.0 \
  --namespace envoy-gateway-system --create-namespace \
  -f week4/day2/labs/envoy-gateway/values.yaml

kubectl apply -f week4/day2/labs/envoy-gateway/gatewayclass.yaml   # GatewayClass 직접 생성
```
- ⚠️ **`https://gateway.envoyproxy.io`는 문서 사이트지 Helm repository가 아님** → `helm repo add` 대상이 아니다. chart는 DockerHub **OCI registry**(`oci://docker.io/envoyproxy/gateway-helm`)에 있음.
- ⚠️ OCI 설치는 **`--version` 명시**가 표준 (여기선 `v1.8.0`). repo index가 없어 latest 자동 선택이 안 되기 때문.
- ⭐ **GatewayClass는 chart가 자동 생성하지 않음** → `gatewayclass.yaml`을 직접 apply해야 함:
```yaml
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller   # 이 controller가 처리
```
- values는 최소 설정: `deployment.replicas: 1`, `logging.level.default: info`.
- `--create-namespace` = envoy-gateway-system namespace 없으면 생성.

### 설치 후 확인 레이어
```bash
helm list -n envoy-gateway-system                          # deployed
kubectl -n envoy-gateway-system get deploy,pod,svc         # controller 1/1 Running
kubectl get crd | grep gateway.networking.k8s.io           # CRD 등록 (chart가 만듦)
kubectl get gatewayclass                                   # envoy-gateway (내가 apply한 것)
```
- ⭐ **Gateway API CRD**(chart가 설치)가 있어야 GatewayClass/Gateway/HTTPRoute object를 만들 수 있음:
```text
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
```
- ⚠️ **CRD(종류 정의)** 는 chart가 설치하지만 **GatewayClass(실제 object)** 는 내가 `gatewayclass.yaml`로 직접 만듦 → 둘은 다른 층. CRD 없이 apply하면 `no matches for kind "GatewayClass"`.
- **GatewayClass** = "이 Gateway를 어떤 구현체가 처리하나" (Ingress의 `ingressClassName` 위치, 더 명시적).

### controller log 단서
| log 단서 | 의미 |
|---|---|
| GatewayClass accepted | controller가 class 인식 |
| Gateway accepted | listener 설정 처리 |
| HTTPRoute attached | route가 Gateway에 붙음 |
| backend not found | Service 이름/namespace 오류 |
| invalid backend port | Service port 오류 |

### port-forward로 확인 (kind는 LoadBalancer 외부 IP 안 뜸)
```bash
kubectl get svc -A | grep envoy                                    # Envoy Service 찾기
kubectl -n envoy-gateway-system port-forward svc/<envoy-svc> 8080:80
curl -H "Host: paperclip.local" http://localhost:8080/
```
- ⚠️ 아직 HTTPRoute가 없으면 **404 정상** (controller 죽은 게 아니라 route가 없는 것). route는 4교시.

### 장애 판단
| 증상 | 확인 |
|---|---|
| chart 못 찾음 / pull 실패 | OCI 경로·`--version` 확인 (`oci://docker.io/envoyproxy/gateway-helm`, `v1.8.0`). repo add 아님 |
| controller Pod Pending | `describe pod` |
| GatewayClass 없음 | `kubectl get gatewayclass` |
| Gateway Accepted 아님 | `describe gateway paperclip-gateway` |
| HTTPRoute 안 붙음 | `describe httproute paperclip-routes` |
| localhost 접근 실패 | Envoy Service 이름, port-forward 대상 |

### 한 줄 요약
> **Gateway API는 traffic 의도를 GatewayClass/Gateway/HTTPRoute로 선언하고, Envoy Gateway controller가 그 의도를 Envoy data plane으로 반영한다.**

## 실습 확인 기록

### ① Helm 설치 — OCI registry에서 envoy-gateway release
```text
$ helm upgrade --install envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
    --version v1.8.0 --namespace envoy-gateway-system --create-namespace \
    -f week4/day2/labs/envoy-gateway/values.yaml
Pulled: docker.io/envoyproxy/gateway-helm:v1.8.0
Digest: sha256:828b0bf1dd0a8312665590802d7e3d0d360560d44ac8afd9f4ce6ed72564c56d
Release "envoy-gateway" has been upgraded. Happy Helming!
NAME: envoy-gateway
NAMESPACE: envoy-gateway-system
STATUS: deployed
REVISION: 2

$ kubectl apply -f week4/day2/labs/envoy-gateway/gatewayclass.yaml
gatewayclass.gateway.networking.k8s.io/envoy-gateway created
```
- 읽는 포인트:
  - ⭐ **`Pulled: docker.io/envoyproxy/gateway-helm:v1.8.0`** = OCI registry에서 chart를 직접 당겨옴 (repo add 없이). `Digest`로 정확한 이미지 검증.
  - `has been upgraded / REVISION 2` = 두 번째 적용 (첫 설치였다면 `does not exist. Installing it now. / REVISION 1`).
  - ⭐ **GatewayClass는 `kubectl apply`로 별도 생성** — chart 자동 아님. 이 두 명령이 3교시 설치의 전부.
  - "may take a few minutes to install" = controller Pod가 Ready 되기까지 시간 걸릴 수 있음 → 바로 확인 안 되면 대기.

### ② controller Pod + CRD + GatewayClass
```text
$ kubectl -n envoy-gateway-system get deploy,pod,svc
deployment.apps/envoy-gateway   1/1   1   1   24m
pod/envoy-gateway-6c8699d485-8sjnr   1/1   Running   0   24m
service/envoy-gateway   ClusterIP   10.96.158.45   <none>   18000,18001,18002,19001,9443/TCP

$ kubectl get crd | grep gateway.networking.k8s.io
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
grpcroutes / tcproutes / tlsroutes / udproutes / referencegrants / backendtlspolicies / listenersets ...

$ kubectl get gatewayclass
NAME            CONTROLLER                                      ACCEPTED   AGE
envoy-gateway   gateway.envoyproxy.io/gatewayclass-controller   True       77s
```
- 읽는 포인트:
  - ⭐ **controller Pod `1/1 Running`** = API object를 감시할 준비.
  - ⭐ **`service/envoy-gateway` 포트가 18000/18001/18002/19001/9443** = 이건 **control plane**(xDS·webhook)용 Service지 사용자 traffic(80/443)용이 아님. **실제 traffic을 받는 data plane Service는 Gateway를 만들어야 생김**(4교시).
  - ⭐ **GatewayClass `ACCEPTED True`** = controller가 이 class를 **받아들여 관리하기 시작**함. 이 class로 Gateway를 만들 수 있는 상태. (False면 controllerName 오타/controller 미동작 의심)
  - **CRD는 chart가 등록** — 사실 3종만이 아니라 10종(grpcroute/tcproute/tlsroute/referencegrant 등)까지 다 깔림. 오늘 쓰는 핵심은 gatewayclasses/gateways/httproutes 3종.
  - **CRD(종류)는 chart가, GatewayClass(실물)는 내가 apply** → 다른 층. CRD 없으면 `no matches for kind "GatewayClass"`.

### ③ data plane은 아직 없음 — port-forward 실패 확인 (controller≠data plane 증거)
```text
$ kubectl get svc -A | grep envoy
envoy-gateway-system   envoy-gateway   ClusterIP   10.96.158.45   <none>   18000,18001,18002,19001,9443/TCP

$ kubectl -n envoy-gateway-system port-forward svc/envoy-gateway 8080:80
error: Service envoy-gateway does not have a service port 80
```
- 읽는 포인트:
  - ⭐ **`does not have a service port 80`** = 지금 있는 `envoy-gateway` Service는 **control plane**(xDS·webhook, 18000~9443)이라 traffic 포트 80이 없음 → port-forward 불가. **이게 정상이고 "controller ≠ data plane"의 직접 증거.**
  - ⭐ **traffic용 data plane Service는 Gateway를 만들어야 생김** (4교시). Envoy Gateway가 Gateway별로 `envoy-week4-<gw>-...` 같은 Service를 `envoy-gateway-system`에 새로 만들어줌 (포트 80 있음).
  - 즉 port-forward + `curl -H "Host: ..."` 확인은 **4교시(Gateway/HTTPRoute 작성 후)** 에 함. HTTPRoute 없으면 404(route 없음)이지 controller 죽음이 아님.

```text
# (4교시에서 Gateway 적용 후 다시)
$ kubectl get svc -n envoy-gateway-system | grep envoy-week4     # data plane Service 등장
$ kubectl -n envoy-gateway-system port-forward svc/<data-plane-svc> 8080:80
$ curl -H "Host: paperclip.local" http://localhost:8080/
```

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| GatewayClass/Gateway/HTTPRoute 역할? | Class=어떤 controller가 처리, Gateway=listener/port, HTTPRoute=host/path routing |
| Ingress와 Gateway API 차이? | Ingress는 한 object에 다 몰림, Gateway API는 역할 분리(platform vs app owner) |
| controller와 data plane 차이? | controller=API object 감시/반영, data plane(Envoy proxy)=실제 traffic 처리 |
| CRD가 왜 필요? | Gateway API CRD가 있어야 GatewayClass/Gateway/HTTPRoute object를 만들 수 있음. CRD는 chart가 설치 |
| GatewayClass는 자동 생성되나? | 아님. chart는 CRD만 설치, GatewayClass object는 `gatewayclass.yaml`로 직접 apply |
| GatewayClass는 Ingress의 무엇과 비슷? | `ingressClassName` (어떤 구현체가 처리할지). Gateway API에선 더 명시적 리소스 |
| Envoy Gateway는 어떻게 설치? | OCI registry `oci://docker.io/envoyproxy/gateway-helm` + `--version v1.8.0`. `gateway.envoyproxy.io`는 문서 사이트라 repo add 안 함 |
| kind에서 왜 port-forward? | LoadBalancer가 외부 IP를 못 받아서. port-forward로 Envoy Service 접근 |
| HTTPRoute 없이 404면 실패? | 아님. route가 없다는 뜻일 수 있음. controller/Gateway 상태를 따로 확인 |

## notes

### Evidence Note
```markdown
# W4D2S3 Envoy Gateway
- Helm release: envoy-gateway (ns envoy-gateway-system, deployed, REVISION 2, chart gateway-helm-v1.8.0)
- controller Pod READY: envoy-gateway-6c8699d485-8sjnr 1/1 Running
- GatewayClass: envoy-gateway (CONTROLLER gateway.envoyproxy.io/gatewayclass-controller, ACCEPTED True)
- Gateway API CRD: gatewayclasses/gateways/httproutes 등 10종 (chart가 설치)
- Envoy Service: control plane envoy-gateway(18000~9443, 80 없음) / data plane는 Gateway 생성 후 envoy-week4-paperclip-gateway-184e87dc(80)
- 설치 방식: oci://docker.io/envoyproxy/gateway-helm --version v1.8.0 (repo add 아님) + gatewayclass.yaml 직접 apply
```

### Ingress 사고방식 → Gateway API 매핑
```text
IngressClass   → GatewayClass
Ingress        → Gateway + HTTPRoute (분리됨)
controller log → Envoy Gateway log
```
- 현장에서 NGINX Ingress를 만나면 같은 사고방식(class→object→controller log)을 그대로 적용.

### OCI registry vs http repo (설치 방식 차이)
```text
metrics-server(W4D1): helm repo add <url> → repo/chart 로 설치   (http Helm repo)
envoy-gateway(오늘):  oci://docker.io/envoyproxy/gateway-helm --version v1.8.0  (OCI registry)
```
- ⚠️ `https://gateway.envoyproxy.io`는 **문서 사이트**지 Helm repo 아님 → `repo add` 하면 실패. OCI는 repo index가 없어 **`--version` 필수**.

### 설치 = add-on 하나가 아니다 (W4D1 3교시 재확인)
- 하나의 helm release가 controller Deployment + CRD 3종 + GatewayClass + RBAC 등을 만듦.
- deployed(Helm) ≠ 동작 → controller Pod Ready + CRD 등록 + GatewayClass 확인까지 레이어로 내려감.

### controller vs data plane (오늘 핵심 구분)
```text
Envoy Gateway controller (envoy-gateway-system)
   → Gateway/HTTPRoute를 보고
      → Envoy proxy(data plane) 설정을 생성/갱신
         → 실제 사용자 traffic은 이 proxy가 처리
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
