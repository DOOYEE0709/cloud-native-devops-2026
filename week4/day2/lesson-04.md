# 4교시: HTTPRoute 작성

## 핵심 정리

### Gateway vs HTTPRoute — 문 vs 라우팅 규칙
```text
Gateway    = "어떤 문을 열 것인가" (listener: protocol/port/hostname)
HTTPRoute  = "어디로 보낼 것인가" (host/path → backend Service)
```
- ⭐ Gateway를 만들면 3교시에서 본 **data plane(Envoy proxy) Pod/Service가 생김**. HTTPRoute는 그 위에 라우팅 규칙을 얹음.

### Gateway manifest
```yaml
kind: Gateway
metadata: { name: paperclip-gateway, namespace: week4 }
spec:
  gatewayClassName: envoy-gateway        # 3교시에서 만든 GatewayClass
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: paperclip.local          # 이 host 기준
      allowedRoutes:
        namespaces: { from: Same }        # 같은 namespace Route만 attach
```

| 필드 | 의미 |
|---|---|
| `gatewayClassName` | Envoy Gateway가 처리할 class |
| `listeners.protocol/port` | HTTP, 80 listener |
| `listeners.hostname` | `paperclip.local` host 기준 |
| `allowedRoutes.namespaces.from: Same` | 같은 namespace의 Route만 붙임 |

### HTTPRoute manifest — path 기반 분기
```yaml
kind: HTTPRoute
metadata: { name: paperclip-routes, namespace: week4 }
spec:
  parentRefs:
    - name: paperclip-gateway            # 이 Gateway에 붙음
  hostnames: [paperclip.local]
  rules:
    - matches: [{ path: { type: PathPrefix, value: /api } }]
      backendRefs: [{ name: api, port: 80 }]        # /api → api Service
    - matches: [{ path: { type: PathPrefix, value: / } }]
      backendRefs: [{ name: frontend, port: 80 }]   # / → frontend Service
```

| 필드 | 의미 |
|---|---|
| `parentRefs` | 어떤 Gateway에 붙을지 |
| `hostnames` | 어떤 Host header와 매칭 |
| `matches.path` | path 조건 (PathPrefix) |
| `backendRefs.name/port` | 연결할 Service와 port |

### PathPrefix — 하위 경로도 같은 backend
| 요청 | backend |
|---|---|
| `/api`, `/api/orders` | api Service |
| `/`, `/about` | frontend Service |

- ⭐ 겹칠 때 **더 구체적인 path(`/api`)가 먼저** → `/api`와 `/`를 함께 둘 수 있음.

### 적용 후 확인 — "보인다 ≠ traffic 성공"
```bash
kubectl -n week4 get gateway,httproute
kubectl -n week4 describe gateway paperclip-gateway     # Programmed/Accepted
kubectl -n week4 describe httproute paperclip-routes    # Accepted, ResolvedRefs
```

| 리소스 | 확인할 condition |
|---|---|
| Gateway | `Accepted` / `Programmed` True |
| HTTPRoute | `Accepted`, **`ResolvedRefs`** (backend Service 해석됨) |
| Service | `frontend`, `api` 존재 |
| EndpointSlice | Ready endpoint 존재 |

- ⭐ HTTPRoute가 보여도 **Gateway에 attach + backendRefs가 Service로 해석(ResolvedRefs)** 돼야 traffic 성공.

### curl로 확인 — Host header가 핵심
```bash
# 터미널1: data plane Service로 port-forward (control plane 아님!)
kubectl get svc -A | grep envoy
kubectl -n envoy-gateway-system port-forward svc/envoy-week4-paperclip-gateway-<hash> 8080:80

# 터미널2
curl -H "Host: paperclip.local" http://localhost:8080/       # → frontend HTML
curl -H "Host: paperclip.local" http://localhost:8080/api    # → api JSON
```
- ⚠️ **`Host: paperclip.local` 헤더 필수.** Gateway listener·HTTPRoute host가 `paperclip.local`이라 host 안 맞으면 **404**. `curl http://localhost:8080/`(host 없음)은 404 가능.
- browser로 볼 땐 hosts 파일에 `127.0.0.1 paperclip.local` 추가 → `http://paperclip.local:8080/`.

### Docker reverse proxy와 비교
```text
nginx: location /api { proxy_pass http://api:8080; }   (설정 파일)
K8s:   HTTPRoute /api → api Service:80 → EndpointSlice → api Pod:8080   (API object)
```
- ⭐ routing이 **Kubernetes object**라 Git 저장·Argo CD sync·Kyverno 정책이 가능 (GitOps).

### 한 줄 요약
> **Gateway는 traffic을 받을 문(listener), HTTPRoute는 host/path 조건으로 backend Service를 고르는 routing 계약이다. Host header가 맞아야 라우팅된다.**

## 실습 확인 기록

### ① Gateway 적용 → data plane 생성
```text
$ kubectl apply -f week4/day2/labs/traffic-routing/gateway.yaml
gateway.gateway.networking.k8s.io/paperclip-gateway created

$ kubectl get pods -A | grep envoy
envoy-gateway-6c8699d485-8sjnr                            1/1   Running   ← controller
envoy-week4-paperclip-gateway-184e87dc-6b549fdc6c-c5fsk   0/2 → 2/2 Running   ← data plane 새로 생김

$ kubectl get svc -A | grep envoy
envoy-gateway                            ClusterIP      ...   18000,...,9443/TCP    ← control plane
envoy-week4-paperclip-gateway-184e87dc   LoadBalancer   ...   <pending>   80:31772/TCP  ← data plane(80!)
```
- 읽는 포인트:
  - ⭐ **Gateway를 만들자 data plane Pod/Service가 생김** = 3교시의 "controller≠data plane" 완성. 이제 **포트 80**이 있는 Service 등장.
  - **`EXTERNAL-IP <pending>`** = kind엔 클라우드 LoadBalancer가 없어 외부 IP 못 받음 → **port-forward로 접근**(정상).
  - data plane Pod `2/2` = Envoy proxy container들이 다 Ready.

### ② HTTPRoute 적용 → Accepted/ResolvedRefs
```text
$ kubectl apply -f week4/day2/labs/traffic-routing/httproute.yaml
httproute.gateway.networking.k8s.io/paperclip-routes created

$ kubectl -n week4 get gateway,httproute
NAME                CLASS           ADDRESS   PROGRAMMED   AGE
paperclip-gateway   envoy-gateway             False        12m
NAME               HOSTNAMES             AGE
paperclip-routes   ["paperclip.local"]   5s

$ kubectl -n week4 describe httproute paperclip-routes | grep -A3 Conditions
    Conditions:
      Message:  Route is accepted
      Reason:   Accepted
      Status:   True
      Type:     Accepted
```
- 읽는 포인트:
  - ⚠️ **Gateway `PROGRAMMED False`** — 놀라지 말 것. kind는 LoadBalancer 외부 IP가 `<pending>`이라 **주소 미할당(AddressNotAssigned)** 으로 False가 뜸. **라우팅 자체는 정상**(아래 ③ curl로 확인됨). 진짜 실패면 curl도 안 됨.
  - ⭐ **HTTPRoute `Accepted True`** = Gateway에 붙음. `ResolvedRefs`도 True여야 backend(api/frontend) 해석 완료 (전체 conditions는 `grep -A30`으로 확인). 둘 다 True면 traffic OK.

### ③ curl — host/path 라우팅 확인
```text
# 터미널1
$ kubectl -n envoy-gateway-system port-forward \
    svc/envoy-week4-paperclip-gateway-184e87dc 8080:80
Forwarding from 127.0.0.1:8080 -> 10080

# 터미널2
$ curl -H "Host: paperclip.local" http://localhost:8080/
<!doctype html>
<html lang="ko">
  <title>Paperclip W4D2 Frontend</title>
  <h1>Paperclip W4D2 Frontend</h1>          ← / → frontend

$ curl -H "Host: paperclip.local" http://localhost:8080/api
{"service":"api","version":"v1","status":"ok"}     ← /api → api
```
- 읽는 포인트:
  - ⭐ **같은 :8080인데 path로 backend가 갈림** — `/`→frontend HTML, `/api`→api JSON. HTTPRoute의 PathPrefix가 동작.
  - ⭐ **`Host: paperclip.local` 필수** — 빼면 매칭 실패. "traffic이 안 가요"의 흔한 원인 1순위.
  - port-forward는 반드시 **data plane Service**(`envoy-week4-...`)로. control plane(`envoy-gateway`)엔 80 없음.

### ④ 브라우저 확인 — hosts 파일 필요 (Host header 함정)
```text
$ curl ...  → 잘 됨 (Host: paperclip.local 명시)
브라우저 http://localhost:8080/  → 안 됨 (Host: localhost → 매칭 실패)

# 해결: hosts에 매핑 추가
$ echo "127.0.0.1 paperclip.local" | sudo tee -a /etc/hosts
# 브라우저 주소창: http://paperclip.local:8080/   ← 이제 Host: paperclip.local
```
- 읽는 포인트:
  - ⭐ **curl은 되는데 브라우저는 안 되는 이유 = Host header.** curl은 `-H`로 `paperclip.local`을 보내지만 브라우저 `localhost:8080`은 `Host: localhost`를 보냄 → Gateway host와 불일치.
  - hosts에 `127.0.0.1 paperclip.local` 추가 후 **`paperclip.local:8080`으로 접속**해야 브라우저가 올바른 Host를 보냄. (`localhost:8080` 아님)
  - ⚠️ Gateway `PROGRAMMED False`(kind는 LB 외부IP `<pending>`)여도 **port-forward 경로로 traffic은 정상**. PROGRAMMED False = 외부 주소 미할당이지 라우팅 실패가 아님.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Gateway와 HTTPRoute 역할 차이? | Gateway=listener(문, protocol/port/host), HTTPRoute=host/path→backend Service 라우팅 |
| Gateway를 만들면 뭐가 생기나? | data plane(Envoy proxy) Pod + 포트 80 Service. 여기로 traffic이 들어옴 |
| HTTPRoute가 보이면 traffic 성공? | 아님. Accepted(attach) + ResolvedRefs(backend 해석)까지 True여야 함 |
| `/api`와 `/`가 어떻게 갈리나? | PathPrefix 매칭, 더 구체적인 `/api`가 우선. 하위 경로도 같은 backend |
| curl에 Host 헤더가 왜 필요? | Gateway/Route host가 paperclip.local이라 안 맞으면 404. host 기반 라우팅 |
| port-forward는 어느 Service로? | data plane(`envoy-week4-...`, 80 있음). control plane(`envoy-gateway`)은 80 없음 |
| kind에서 EXTERNAL-IP <pending>인 이유? | 클라우드 LB가 없어 외부 IP 미할당. port-forward로 대체 |

## notes

### Evidence Note
```markdown
# W4D2S4 HTTPRoute
- Gateway name: paperclip-gateway (listener http, port 80, hostname paperclip.local)
- GatewayClass: envoy-gateway
- HTTPRoute parentRefs: paperclip-gateway (name paperclip-routes, Accepted True)
- `/` backend: frontend Service:80
- `/api` backend: api Service:80
- curl `/` result: Paperclip W4D2 Frontend HTML (200)
- curl `/api` result: {"service":"api","version":"v1","status":"ok"}
- data plane Service: envoy-week4-paperclip-gateway-184e87dc (LoadBalancer 80, EXTERNAL-IP <pending>) → port-forward 8080:80
- 브라우저: hosts에 127.0.0.1 paperclip.local 추가 후 http://paperclip.local:8080/ (Host header 때문)
```

### 전체 traffic 경로 (오늘 완성)
```text
curl -H "Host: paperclip.local" :8080/api
  → port-forward → data plane(Envoy proxy)
    → Gateway listener(paperclip.local:80)
      → HTTPRoute rule(/api)
        → api Service:80
          → EndpointSlice(api Pod:8080 ×2)
            → api Pod
```
- 1교시 "장애 판단 순서(Gateway→HTTPRoute→Service→Endpoint→Pod)"가 이 경로의 역순.

### "안 될 때" 자주 걸리는 곳
| 증상 | 원인 |
|---|---|
| 404 (route 있음) | Host 헤더 누락/오타 (`paperclip.local`) |
| ResolvedRefs False | backendRefs 이름/port 오타, Service 없음 |
| Gateway PROGRAMMED 아님 | GatewayClass/controller 문제 |
| port-forward 포트 없음 | control plane Service를 잘못 지정 |

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
