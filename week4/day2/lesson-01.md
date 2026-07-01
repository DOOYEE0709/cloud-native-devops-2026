# 1교시: Day1 요약 + Kubernetes Networking 다시 잡기

> ⚠️ 강의안은 **day별 cluster**를 씀 → 오늘 cluster는 **`paperclip-w4d2`**. (W4D1은 `paperclip-w4`) 첫 명령은 `apply`가 아니라 **context 고정**.

## 핵심 정리

### Day1에서 가져올 한 문장
```text
Running ≠ Ready. Ready가 아니면 Service endpoint에서 빠진다.
```
- ⭐ W4D2는 이게 **외부 traffic 장애**로 어떻게 번지는지 본다:
```text
Pod Running → readiness 실패 → Endpoint 없음
  → Service는 있지만 backend 없음 → Gateway 경로에서 503 계열
```
- 즉 **"Service가 있다" ≠ "traffic 갈 endpoint가 있다"** 를 구분하는 게 오늘 핵심.

### cluster를 먼저 고정 (context)
```bash
bash week4/scripts/create-kind-cluster.sh paperclip-w4d2
bash week4/scripts/ensure-kind-context.sh paperclip-w4d2
kubectl config current-context      # kind-paperclip-w4d2
kubectl get nodes                    # Ready
```
- ⚠️ 이 확인을 건너뛰면 지난 cluster·Docker Desktop 기본 cluster에 manifest가 적용될 수 있음. **중요 작업 전마다** context 재확인.
- evidence에 반드시 **current-context**를 남긴다.

### 내부 traffic 흐름 — Pod IP가 아니라 Service
```text
[내부] frontend Pod → api Service DNS → api Endpoint → api Pod IP:containerPort
[외부] 사용자 → Envoy Gateway data plane → Gateway listener → HTTPRoute rule
        → Service → Endpoint → Pod
```
- ⭐ Pod끼리 **Pod IP로 직접 통신 안 함** (Pod IP는 바뀜). Service DNS로 호출 → Service가 Endpoint를 갱신해 변화를 감춤.
- HTTPRoute도 **Pod로 직접 안 보내고 Service로** 보냄 → 이 감각이 있어야 Gateway API가 이해됨.

### svc/endpoints 출력 읽기 — port 매핑 & backend 유무
| 출력 | 의미 |
|---|---|
| `service/api 80/TCP` | Service가 받는 port = 80 |
| `endpoints/api 10.244.x.x:8080` | 실제 Pod containerPort = 8080 |
| Endpoint 2개 | Ready Pod 2개 |
| Endpoint `<none>` | traffic 보낼 Pod 없음 (Service만 존재) |

### selector가 traffic을 결정
```yaml
# Service              # Pod
selector:              labels:
  app: api               app: api
```
- ⭐ Service는 이름이 아니라 **label selector**로 Pod를 찾음. selector ≡ label이 **맞아야 Endpoint 생성**. (W4D1 5교시 readiness와 함께 endpoint를 좌우하는 두 축: selector 매칭 + readiness 통과)

### DNS 이름 — 짧은 이름 vs FQDN
```text
같은 namespace:  http://api
전체(FQDN):      api.week4.svc.cluster.local
```
- DNS 실패 시 app log보다 먼저 **Service 이름·namespace·CoreDNS·NetworkPolicy DNS egress** 확인.
- `nslookup`으로 DNS 실패와 connection 실패를 구분:
```bash
kubectl -n week4 run dnscheck --rm -it --restart=Never \
  --image=busybox:1.36 -- nslookup api
```

### 왜 Pod IP로 직접 호출하지 않나
```text
Pod IP 변경(rollout/reschedule/node 재시작)
  → Endpoint 갱신 → Service DNS는 그대로 → client는 http://api 계속 사용
```
- Pod IP로 직접 부르면 처음엔 되지만 rollout 후 깨짐. Service가 이 변화를 흡수.

### 오늘의 장애 판단 순서 (위→아래로 좁히기)
| 순서 | 명령 | 판단 |
|---|---|---|
| 1 | `get gateway,httproute` | Gateway/Route가 있나 |
| 2 | `describe httproute paperclip-routes` | parentRefs·host/path·backendRefs 맞나 |
| 3 | `get svc,endpoints` | Service·Endpoint 있나 |
| 4 | `get pod` | Ready Pod 있나 |
| 5 | `-n envoy-gateway-system logs deploy/envoy-gateway` | controller가 처리했나 |

### 한 줄 요약
> **Kubernetes traffic 장애는 Gateway → HTTPRoute → Service → Endpoint → Pod readiness를 순서대로 좁혀야 한다. "Service가 있다"와 "traffic 갈 endpoint가 있다"는 다르다.**

## 실습 확인 기록

### ① context 고정 — 오늘 cluster 확인
```text
$ kubectl config current-context
kind-paperclip-w4d2

$ kubectl get nodes
NAME                              STATUS   ROLES           AGE   VERSION
paperclip-w4d2-control-plane      Ready    control-plane   ...   v1.xx.x
```
- 읽는 포인트:
  - ⭐ 첫 명령이 apply가 아니라 **context 확인**. 엉뚱한 cluster에 적용하는 사고를 여기서 차단.
  - node 이름에 `w4d2` = 오늘 cluster가 맞음 (W4D1의 `paperclip-w4`와 구분).

### ② Pod / svc / endpoints — 구성요소 관찰
```text
$ kubectl -n week4 get pod -o wide
NAME                        READY   STATUS    IP           NODE
api-7d5f896774-j7wmr        1/1     Running   10.244.0.7   paperclip-w4d2-control-plane
api-7d5f896774-khdbb        1/1     Running   10.244.0.8   paperclip-w4d2-control-plane
frontend-7d66f6d9cb-k24m5   1/1     Running   10.244.0.5   paperclip-w4d2-control-plane
frontend-7d66f6d9cb-zcv6s   1/1     Running   10.244.0.6   paperclip-w4d2-control-plane
postgres-5f945bcf7f-6xfmn   1/1     Running   10.244.0.9   paperclip-w4d2-control-plane
```
- 읽는 포인트:
  - 3개 앱: **frontend ×2, api ×2**(replica 2, 로드 분산 대상), **postgres ×1**(db). 다 `1/1 Running` = readiness 통과 → endpoint 후보.
  - 모두 같은 node(`paperclip-w4d2-control-plane`) = kind라 node 하나뿐. Pod IP는 `10.244.0.x`(같은 Pod CIDR).
  - ⭐ Pod IP(`10.244.0.7` 등)는 실제 도착지지만 **고정값으로 쓰면 안 됨** (rollout하면 바뀜) → Service DNS로 부름.
```text
$ kubectl -n week4 get endpoints api
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME   ENDPOINTS                         AGE
api    10.244.0.7:8080,10.244.0.8:8080   15m
```
- ⭐ Endpoint = **`10.244.0.7:8080`, `10.244.0.8:8080`** = api Pod 2개 IP + **포트 8080**. Service의 `targetPort: http`가 실제 **8080으로 풀린 결과**(named port → 숫자). Pod IP가 붙어 있으면 backend 정상, `<none>`이면 없음.
- `Endpoints deprecated → EndpointSlice` 경고 = 요즘은 EndpointSlice가 원본 (W4D1 5교시에서도 본 경고).

### ③ selector 매칭 & DNS 조회
```text
$ kubectl -n week4 get svc api -o yaml
spec:
  clusterIP: 10.96.139.43
  ports:
  - name: http
    port: 80
    targetPort: http        ← 숫자가 아니라 "http"(named port)!
  selector:
    app: api                ← 이 label을 가진 Pod로 traffic

$ kubectl -n week4 get pod -l app=api
NAME                   READY   STATUS
api-7d5f896774-j7wmr   1/1     Running     ← selector와 label이 맞아 잡힘
api-7d5f896774-khdbb   1/1     Running
```
- 읽는 포인트:
  - ⭐ Service selector(`app: api`) ≡ Pod label(`app: api`) → 이 Pod 2개가 Endpoint가 됨. 불일치면 Endpoint `<none>`. (5교시에서 일부러 selector 틀린 `broken-service-wrong-selector.yaml`로 이 실패를 봄)
  - ⭐ **`targetPort: http`** = 숫자(8080)가 아니라 **container에 정의된 named port "http"** 를 가리킴. Pod spec의 `ports: - name: http, containerPort: 8080`을 참조 → 컨테이너 포트가 바뀌어도 이름만 맞으면 됨.
  - `port: 80`(Service가 받음) → `targetPort: http`(Pod의 8080) 매핑. 사용자는 `http://api`(=80)로 부르고 내부는 8080으로 감.
  - `clusterIP: 10.96.139.43` = Service의 가상 IP. DNS `api`가 이 IP로 resolve됨.
```text
$ kubectl -n week4 run dnscheck --rm -it --restart=Never \
    --image=busybox:1.36 -- nslookup api
Server:  10.96.0.10                                    ← CoreDNS
** server can't find api.cluster.local: NXDOMAIN       ← search 1 실패(정상 노이즈)
Name:    api.week4.svc.cluster.local
Address: 10.96.139.43                                  ← ✅ 성공 (Service clusterIP)
** server can't find api.svc.cluster.local: NXDOMAIN   ← search 3 실패(정상 노이즈)
```
- 읽는 포인트:
  - ⭐ **`api.week4.svc.cluster.local → 10.96.139.43`(clusterIP) 성공** = DNS 정상. curl 실패 시 DNS 문제인지 connection 문제인지 여기서 갈림.
  - **NXDOMAIN 여러 줄은 정상** — busybox가 DNS **search domain을 순서대로**(`api.cluster.local` → `api.week4.svc.cluster.local` → …) 시도하며 안 맞는 건 NXDOMAIN, 맞는 건 성공. 중간에 성공한 줄만 보면 됨.
  - `Server 10.96.0.10` = CoreDNS(kube-dns) Service IP. 질의가 CoreDNS로 감.
  - `terminated (Error)`는 busybox가 일부 NXDOMAIN으로 non-zero exit하는 버릇 → 조회 자체는 성공.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| "Service가 있다"와 "traffic 갈 endpoint가 있다"의 차이? | Service 존재해도 Ready Pod가 없으면 Endpoint `<none>` → backend 없어 503 계열 |
| Pod끼리 Pod IP로 직접 통신 안 하는 이유? | Pod IP는 rollout/reschedule로 바뀜. Service DNS+Endpoint가 변화를 흡수 |
| Endpoint는 언제 생기나? | Service selector ≡ Pod label 매칭 + Pod가 readiness 통과(Ready)일 때 |
| Service port와 Pod containerPort 관계? | Service `:80` → Pod `:8080`처럼 Service가 매핑. 둘은 다를 수 있음 |
| 같은 namespace에서 api Service 호출? | `http://api` (FQDN: `api.week4.svc.cluster.local`) |
| DNS 실패 시 먼저 볼 곳? | app log 아님. Service 이름·namespace·CoreDNS·NetworkPolicy DNS egress |
| traffic 장애 판단 순서? | Gateway → HTTPRoute → Service → Endpoint → Pod readiness (위→아래) |

## notes

### Evidence Note
```markdown
# W4D2S1 Networking recap
- current-context: kind-paperclip-w4d2 (node paperclip-w4d2-control-plane)
- frontend Pod IP: 10.244.0.5, 10.244.0.6 (replica 2)
- api Service ClusterIP: 10.96.139.43 (port 80 → targetPort http)
- api Endpoint: 10.244.0.7:8080, 10.244.0.8:8080
- Service selector: app=api (Pod label과 일치 → endpoint 생성)
- DNS 조회 결과: api → api.week4.svc.cluster.local → 10.96.139.43 (정상)
- Endpoint가 `<none>`이면 볼 것: selector≡label, Pod readiness
```

### Endpoint를 좌우하는 두 축 (W4D1 5교시 연결)
```text
Endpoint에 Pod가 붙으려면:
  1) selector ≡ label  (소속)      ← 오늘 selector
  2) readiness 통과    (준비)      ← W4D1 5교시 probe
둘 중 하나만 어긋나도 Endpoint에서 빠짐 → Service는 있어도 backend 없음
```

### 내부 vs 외부 traffic 경로
```text
내부: Pod → Service DNS → Endpoint → Pod
외부: 사용자 → Envoy Gateway → listener → HTTPRoute → Service → Endpoint → Pod
```
- HTTPRoute가 **Service로** 보낸다는 점이 오늘~3·4교시(Gateway API/HTTPRoute)의 핵심 전제.

### ⚠️ cluster/labs 준비 메모
- 오늘 cluster는 `paperclip-w4d2` (day별 분리). context 먼저 고정.
- day2 실습 manifest(`labs/traffic-routing/`)는 **cloud repo에 아직 없음** → lecture repo에서 가져오거나 별도 sync 필요.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
