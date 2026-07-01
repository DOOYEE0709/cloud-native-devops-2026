# 5교시: Gateway/HTTPRoute 장애 분석

## 핵심 정리

### 장애 분석 순서 — app log가 아니라 층별 condition
```text
curl/browser 증상
  → Envoy data plane 접근 가능?
    → Gateway listener condition (Accepted/Programmed)
      → HTTPRoute parentRefs/Accepted/ResolvedRefs
        → Service name/port
          → EndpointSlice 존재
            → Pod readiness
              → Envoy Gateway controller log
```
- ⭐ 처음부터 app log만 보면 **traffic이 app까지 도달 못 한 경우**를 놓침. Gateway API는 **object의 condition이 증거**.

### 증상별 첫 판단 — 404/503/refused/timeout은 다른 것
| 증상 | 원인 후보 | 먼저 볼 명령 |
|---|---|---|
| **404** | host/path 불일치, HTTPRoute attach 안 됨 | `describe httproute` |
| **503** | endpoint 없음, readiness 실패 | `get endpointslice`, `get endpoints` |
| **connection refused** | port-forward/data plane Service 문제 | `get svc -A \| grep envoy` |
| **timeout** | NetworkPolicy, backend 지연 | endpoint, networkpolicy, logs |
| **DNS failure** | hosts/CoreDNS/Service 이름 | hosts, svc, CoreDNS |

- ⭐ curl 출력을 **한 덩어리로 보지 않기.** 404(라우팅) vs 503(backend) vs refused(접근)는 층이 다름.

### 장애 1: HTTPRoute parentRefs 오류 → Accepted False
```bash
kubectl apply -f week4/day2/labs/traffic-routing/broken-httproute-wrong-parent.yaml
kubectl -n week4 describe httproute paperclip-routes-wrong-parent
```
- manifest에 `parentRefs: name: missing-gateway` (존재하지 않는 Gateway).
- ⭐ Route는 **생성되지만** 맡을 controller가 없어 **`Status:` 섹션이 아예 안 생김** (Accepted False가 아니라 status 부재). 정상 route엔 있는 `Parents → Accepted True`가 통째로 없음.

### 장애 2: Service selector 오류 → Endpoint `<none>`
```bash
kubectl apply -f week4/day2/labs/traffic-routing/broken-service-wrong-selector.yaml
kubectl -n week4 get svc,endpoints api-broken-selector
```
- selector가 `app: api-missing` (실제 Pod label은 `app=api`).
- ⭐ **Service는 있지만 Endpoint `<none>`** — DNS/ClusterIP는 생기지만 traffic 받을 Pod가 없음. (1교시 "Service 있다 ≠ endpoint 있다"의 실물)

### 장애 3: backendRefs port 오류 → ResolvedRefs False
```bash
kubectl apply -f week4/day2/labs/traffic-routing/broken-httproute-wrong-port.yaml
kubectl -n week4 describe httproute paperclip-routes-wrong-port
```
- backendRef `port: 9999` (api Service는 80만 제공).
- ⭐ HTTPRoute는 **Service의 `port`(80)** 를 참조해야 함. 9999는 Service에 없어 **ResolvedRefs False** → traffic 실패.
- ⚠️ 헷갈림: backendRef port는 **Service port(80)** 지 Pod containerPort(8080)가 아님.

### 장애 4: readiness 실패 → endpoint 빠짐 (503)
```bash
kubectl -n week4 get pod
kubectl -n week4 get endpoints api
kubectl -n week4 describe pod -l app=api
```
- Pod `0/1 Running` + `Readiness probe failed` → endpoint에서 빠짐 → **Gateway/HTTPRoute 정상이어도 503**. (W4D1 5교시 그대로)

### condition 3종 정리
| condition | 무슨 층 | False면 |
|---|---|---|
| **Accepted** | HTTPRoute가 Gateway에 attach | parentRefs(Gateway 이름) 오류 |
| **ResolvedRefs** | backendRef가 Service로 해석 | Service 이름/port 오류 |
| **Programmed** | Gateway가 data plane에 반영 | GatewayClass/controller/주소 |

### 정상 vs 문제 비교
| 비교 | 정상 | 문제 |
|---|---|---|
| parentRefs | `paperclip-gateway` | 없는 Gateway → Accepted False |
| backend port | `80`(Service port) | `9999` → ResolvedRefs False |
| endpoint | Pod IP 목록 | `<none>`(selector/readiness) |
| Pod READY | `1/1` | `0/1` |

### 한 줄 요약
> **Gateway API 장애는 404(라우팅)/503(backend)/refused(접근)를 나누고, Accepted·ResolvedRefs·Programmed condition으로 층별로 좁힌다.**

## 실습 확인 기록

### ① 장애1 — parentRefs 오류 (Status 자체가 없음)
```text
$ kubectl apply -f week4/day2/labs/traffic-routing/broken-httproute-wrong-parent.yaml
httproute.gateway.networking.k8s.io/paperclip-routes-wrong-parent created

$ kubectl -n week4 describe httproute paperclip-routes-wrong-parent
...
Spec:
  Parent Refs:
    Kind:   Gateway
    Name:   missing-gateway      ← 존재하지 않는 Gateway
  Rules: ...
Events:         <none>
    (Status: 섹션이 아예 없음 — grep Conditions에도 아무것도 안 잡힘)
```
- 읽는 포인트:
  - ⭐ **`Status:` 섹션이 통째로 없음** (Accepted False가 아니라 **아무 status도 없음**). `missing-gateway`는 존재하지 않아 **이 Route를 맡을 controller가 없음** → 상태를 안 남김. "거부"가 아니라 "아무도 안 봄".
  - ⭐ 정상 `paperclip-routes`는 `Status → Parents → Accepted: True`가 있음 → **status 존재 여부 자체**가 attach 성공/실패의 신호.
  - 즉 parentRefs 오류의 실전 증상 = **describe에 Status/Parents가 비어있음** (조건 False를 찾지 말고 "조건이 아예 없음"을 볼 것).

### ② 장애2 — Service selector 오류 (Endpoint <none>)
```text
$ kubectl apply -f week4/day2/labs/traffic-routing/broken-service-wrong-selector.yaml
service/api-broken-selector created

$ kubectl -n week4 get svc,endpoints api-broken-selector
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME                          TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/api-broken-selector   ClusterIP   10.96.9.241   <none>        80/TCP    0s

NAME                            ENDPOINTS   AGE
endpoints/api-broken-selector   <none>      0s

$ kubectl -n week4 get svc api-broken-selector -o yaml
spec:
  selector:
    app: api-missing        ← Service가 찾는 label

$ kubectl -n week4 get pod --show-labels | grep api
api-7d5f896774-j7wmr   1/1   Running   ...   app=api,pod-template-hash=7d5f896774,tier=api
api-7d5f896774-khdbb   1/1   Running   ...   app=api,pod-template-hash=7d5f896774,tier=api
```
EndpointSlice로 보면 정상/문제가 나란히 대조됨:
```text
$ kubectl -n week4 get endpointslice
NAME                        ADDRESSTYPE   PORTS     ENDPOINTS               AGE
api-broken-selector-9kr5r   IPv4          <unset>   <unset>                 7m40s    ← 비어있음
api-btrjb                   IPv4          8080      10.244.0.7,10.244.0.8   153m     ← 정상 api
frontend-cgtv6              IPv4          80        10.244.0.6,10.244.0.5   153m
postgres-5fppr              IPv4          5432      10.244.0.9              153m
```
- 읽는 포인트:
  - ⭐ **Service 존재(`ClusterIP 10.96.9.241`, `80/TCP`) + Endpoint `<none>`** = selector(`app=api-missing`)가 어떤 Pod label과도 안 맞아 backend 0개. ClusterIP·DNS는 생기지만 traffic 못 감 → 503 유발.
  - ⭐ **selector `app=api-missing` vs Pod label `app=api`** = 딱 불일치. `--show-labels`로 두 값을 나란히 보면 원인이 명확 (Pod엔 `app=api`, `tier=api`가 있지 `api-missing`은 없음).
  - ⭐ **EndpointSlice**에서 `api-broken-selector`의 slice는 `PORTS <unset> / ENDPOINTS <unset>`(비어있음), 정상 `api`는 `8080 / 10.244.0.7,10.244.0.8` → 한 화면에서 대조됨. (EndpointSlice가 Endpoints의 최신 원본)
  - ⭐ 이건 1교시 "Endpoint를 좌우하는 두 축(selector 매칭 + readiness)" 중 **selector 불일치** 케이스. (readiness 실패는 W4D1 5교시 케이스)

### ③ 장애3 — backendRefs port 오류 (ResolvedRefs False)
```text
$ kubectl apply -f week4/day2/labs/traffic-routing/broken-httproute-wrong-port.yaml
httproute.gateway.networking.k8s.io/paperclip-routes-wrong-port created

$ kubectl -n week4 describe httproute paperclip-routes-wrong-port
Spec:
  Parent Refs:
    Name:   paperclip-gateway         ← 존재하는 Gateway (장애1과 다름)
  Rules:
    Backend Refs:
      Name:  api
      Port:  9999                      ← api Service엔 없는 port
Status:
  Parents:
    Conditions:
      Reason:   Accepted
      Status:   True
      Type:     Accepted
      Message:  Failed to process route rule 0 backendRef 0: TCP Port 9999 not found on Service week4/api.
      Reason:   PortNotFound
      Status:   False
      Type:     ResolvedRefs

$ curl -H "Host: paperclip.local" http://localhost:8080/api
{"service":"api","version":"v1","status":"ok"}
```
비교 — 정상 api Service의 실제 port:
```text
$ kubectl -n week4 get svc api -o yaml
spec:
  ports:
  - name: http
    port: 80              ← api Service가 제공하는 port
    targetPort: http
  selector:
    app: api
```

| | 값 | Service에 있음? |
|---|---|---|
| api **Service** port | `80` | ✅ (targetPort http → Pod 8080) |
| broken **HTTPRoute** backendRef port | `9999` | ❌ → PortNotFound |

- 읽는 포인트:
  - ⭐ **9999 vs 80 대조** = HTTPRoute backendRef port(`9999`)가 api Service가 실제 제공하는 port(`80`)와 달라서 실패. 고치려면 backendRef를 `80`으로. (실습에선 안 고치고 삭제)
  - ⭐ **`Accepted True` + `ResolvedRefs False`** = parentRefs(Gateway)는 맞아 attach는 됐지만, backendRef `port: 9999`가 api Service(80만 있음)에 없어 backend 해석 실패. 장애1(Status 없음)과 달리 **여기선 Status가 생기고 condition이 명확**.
  - ⭐ Message가 원인을 문장으로: **`TCP Port 9999 not found on Service week4/api`**. condition 메시지만 읽어도 진단 끝.
  - ⚠️ backendRef port = **Service port(80)** 지 Pod containerPort(8080) 아님. (2교시 port 3층과 연결)
  - ⚠️ **curl은 여전히 `200`이 나옴!** 정상 route `paperclip-routes`가 아직 살아있어 같은 `/api`를 처리하기 때문. broken route 하나가 깨져도 **정상 route가 masking**함 → "route를 추가했는데 왜 멀쩡하지?"의 함정. 진짜 영향 보려면 정상 route와의 우선순위/중복을 함께 봐야 함.

> 장애4(readiness 실패)는 broken manifest가 없어 **실습 미재현** — W4D1 5교시(bad-readiness, `0/1 Running` + endpoint 빠짐)에서 이미 확인함. 재현하려면 `kubectl -n week4 edit deploy api`로 readinessProbe를 깨야 함(파일 아님, Deployment 수정). 핵심 정리 "장애 4" 참조.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 404와 503의 차이? | 404=host/path/attach 라우팅 문제, 503=backend(endpoint 없음/readiness 실패) |
| readiness 실패 시 Gateway/Route가 정상인데도? | endpoint에서 Pod가 빠져 backend 0개 → 503. Route는 정상이어도 traffic 도착지 없음 |
| Accepted False는 무슨 뜻? | HTTPRoute가 Gateway에 attach 안 됨 (parentRefs 오류 등) |
| ResolvedRefs False는? | backendRef가 Service로 해석 안 됨 (Service 이름/port 오류) |
| Service 있는데 Endpoint <none>이면? | selector가 Pod label과 불일치 or Ready Pod 없음 |
| backendRef port에 8080 쓰면? | 틀림. Service port(80)를 써야 함. 8080은 Pod containerPort |
| 장애 시 app log부터 보면? | 놓침. traffic이 app까지 도달 못 한 경우 많음 → condition/endpoint 먼저 |
| connection refused면? | port-forward/data plane Service 문제 (`get svc -A \| grep envoy`) |

## notes

### Evidence Note
```markdown
# W4D2S5 Gateway troubleshooting
- 내가 본 증상: broken 3종 주입 — wrong-parent / wrong-selector / wrong-port
- HTTP status 또는 curl error: curl /api는 계속 200 (정상 paperclip-routes가 masking). broken route 단독 증상은 condition으로 확인
- Gateway listener/condition: paperclip-gateway PROGRAMMED False (kind LB EXTERNAL-IP <pending> 때문, 라우팅은 정상)
- HTTPRoute parentRefs/backendRefs:
  - wrong-parent(missing-gateway): Status 섹션 자체가 없음 (아무 controller도 안 맡음)
  - wrong-port(api:9999): Accepted True + ResolvedRefs False, Reason PortNotFound ("TCP Port 9999 not found on Service week4/api")
- Service port와 targetPort: api Service port 80 → targetPort http → Pod 8080 (backendRef는 80이어야 함)
- Endpoint 상태: 정상 api 10.244.0.7:8080,10.244.0.8:8080 / api-broken-selector <none> (EndpointSlice ENDPOINTS <unset>)
- Pod READY/event: api 1/1 Ready, readinessProbe http-get /api, Events <none>
- 가장 가능성 높은 원인: ①parentRefs 오타(없는 Gateway) ②selector≠Pod label(app=api-missing vs app=api) ③backendRef port(9999) Service에 없음
```

### condition으로 원인 좁히기 (오늘 핵심)
```text
Status/Parents 없음 → parentRefs가 없는 Gateway (아무도 안 맡음)  [장애1]
Accepted False      → parentRefs가 있지만 attach 거부되는 경우
ResolvedRefs False  → backendRef Service 이름/port 문제      [장애3]
Endpoint <none>     → selector 불일치 or readiness 실패      [장애2, 4]
Programmed False    → GatewayClass/controller/주소 (kind는 LB pending 정상)
```
- ⭐ 증상(404/503)만 보지 말고 **어느 condition이 False인지**로 층을 특정.

### 장애 정리 후 원복
```bash
kubectl -n week4 delete httproute paperclip-routes-wrong-parent paperclip-routes-wrong-port --ignore-not-found
kubectl -n week4 delete svc api-broken-selector --ignore-not-found
# 정상 paperclip-routes / api는 그대로 유지
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
