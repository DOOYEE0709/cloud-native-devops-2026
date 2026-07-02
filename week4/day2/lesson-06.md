# 6교시: NetworkPolicy와 Cilium/Hubble Preview

## 핵심 정리

### NetworkPolicy = "누가 누구에게 갈 수 있나"
```text
Service/Gateway = 어디로 보낼 것인가 (라우팅)
NetworkPolicy   = 누가 누구에게 갈 수 있나 (허용선)
```
- ⭐ **namespace는 이름 경계지 자동 방화벽이 아님.** 정책 없으면 다른 namespace Service도 DNS로 호출 가능 → "다르면 못 간다"가 아니라 "**정책/CNI로 막아야 못 간다**".

### ingress vs egress — 방향
| 방향 | 뜻 | 대상 |
|---|---|---|
| **Ingress** | Pod로 **들어오는** traffic 받기 | destination Pod에 검 |
| **Egress** | Pod에서 **나가는** traffic | source Pod에 검 |

- ⭐ **한 통신을 열려면 양쪽 다** 필요할 수 있음: source의 egress 허용 + destination의 ingress 허용. (default deny면 둘 다 막힘)

### 오늘의 허용선 (traffic matrix)
| Source | Destination | 허용? | 이유 |
|---|---|---|---|
| frontend | api | ✅ | 기능 호출 |
| api | postgres | ✅ | 데이터 접근 |
| frontend | postgres | ❌ | db 직접 접근 방지 |
| unknown Pod | api/postgres | ❌ | lateral movement 방지 |
| envoy gateway | frontend/api | ✅ | 외부 진입점이 backend로 |
| app Pod | kube-dns | ✅ | Service DNS 필요 |

### manifest 8종 (default deny + 필요한 것만 열기)
```bash
kubectl apply -f week4/day2/labs/traffic-routing/networkpolicy-preview.yaml
kubectl -n week4 get networkpolicy
```

| Policy | 대상(podSelector) | 방향 | 의미 |
|---|---|---|---|
| `default-deny-all` | `{}` (전체) | Ingress+Egress | 기본 다 차단 |
| `allow-dns-egress` | `{}` (전체) | Egress | kube-dns 53(UDP/TCP) 허용 |
| `allow-frontend-to-api` | `app=api` | Ingress | frontend→api 들어옴 허용 (:8080) |
| `allow-frontend-egress-to-api` | `app=frontend` | Egress | frontend→api 나감 허용 (:8080) |
| `allow-api-to-db` | `app=postgres` | Ingress | api→db 들어옴 허용 (:5432) |
| `allow-api-egress-to-db` | `app=api` | Egress | api→db 나감 허용 (:5432) |
| `allow-envoy-gateway-to-frontend` | `app=frontend` | Ingress | envoy gateway→frontend 허용 (:80) |
| `allow-envoy-gateway-to-api` | `app=api` | Ingress | envoy gateway→api 허용 (:8080) |

- ⭐ **frontend→api 한 경로에 policy가 2개** (frontend egress + api ingress). default deny라 양쪽 다 열어야 통과.
- ⭐ envoy gateway용 2개는 **다른 namespace(envoy-gateway-system)에서 들어오는** ingress → `namespaceSelector` + `podSelector(app.kubernetes.io/name=envoy)` 조합으로 교차 허용. 없으면 Gateway는 정상인데 backend traffic이 막혀 502/timeout.

### ⚠️ DNS egress가 왜 필요한가 — `Could not resolve host` (엄격한 CNI 기준)
```text
default deny egress 적용 → Service 이름 호출 시 DNS(53) 못 나감
  → curl http://api → "Could not resolve host: api"
```
- DNS는 `kube-system`의 CoreDNS로 감 → **다른 namespace로 나가는 53번**을 열어야 함 (`allow-dns-egress`).
- ⚠️ 이때 app이 죽은 게 아니라 **DNS egress가 막힌 것**. DNS 실패와 app 오류를 구분.
- ⚠️ 단, 이번 kindnet(v20260528)에서는 `allow-dns-egress`를 지워도 이름 해석이 계속 됐다(③-b 참고). CNI마다 DNS egress 처리가 다름 → **정책에는 넣는 게 정석**(Cilium/Calico 등 엄격한 CNI에서는 지우면 바로 깨짐).

### selector가 정책의 API — label 설계 = 정책 설계
| selector | 범위 |
|---|---|
| `podSelector: {}` | policy namespace의 **모든** Pod |
| `podSelector.matchLabels.app: api` | 그 namespace의 `app=api` Pod |
| `from.podSelector.app: frontend` | **같은 namespace**의 `app=frontend` |
| `from.namespaceSelector...` | 다른 namespace의 Pod (교차 허용 시 필요) |

- ⭐ NetworkPolicy는 이름이 아니라 **label**로 대상 선택. label 틀리면 정책이 엉뚱한 Pod에 적용/미적용.
- ⚠️ port는 **Pod가 실제 받는 port**(frontend 80, api 8080, db 5432) 기준. Service port와 헷갈리지 말 것.

### ⚠️ CNI마다 enforcement가 다르다 (이번 cluster는 강제됨)
| 환경 | enforcement |
|---|---|
| 예전 kindnet | NetworkPolicy를 적용만 받고 packet 차단은 안 하기도 함 |
| **이번 kindnet v20260528** | **pod↔pod TCP 경로를 실제로 차단함** (아래 traffic matrix 그대로 재현됨) |
| Calico/Cilium | eBPF/iptables로 packet 차단, DNS egress까지 엄격 |

- ⭐ 이번 kindnet은 NetworkPolicy를 **실제 강제**한다(과거 "kind는 설계만" 통설과 다름). 그래서 오늘은 설계뿐 아니라 **차단 결과까지 눈으로 확인**했다.
- ⭐ 목표는 여전히 **"어떤 label/port/방향으로 정책을 쓰는가(설계)"** — 그 설계가 맞으면 강제하는 CNI에서 그대로 동작.

### Gateway API vs NetworkPolicy — 다른 문제
```text
Gateway/HTTPRoute/Service/Endpoint 다 정상인데
  NetworkPolicy가 backend traffic 차단 → timeout/connection 실패
```
- ⭐ 라우팅(Gateway)과 network path 제한(NetworkPolicy)은 **다른 층**. 둘 다 확인.

### Cilium / Hubble preview
| 도구 | 역할 |
|---|---|
| Cilium | eBPF 기반 CNI, NetworkPolicy enforcement |
| CiliumNetworkPolicy | 표준보다 확장된 정책 표현 |
| Hubble | service 간 flow·drop reason 관찰 |

- 남기는 질문: **"Service/DNS/Endpoint는 정상인데 timeout이면 어디서 packet이 drop되나?"** → Hubble이 flow evidence 제공. (W4D5 Istio는 mesh 계층, Cilium은 CNI/eBPF 계층 — 다른 층)

### 한 줄 요약
> **NetworkPolicy는 namespace 자동 격리가 아니라 label 기반 허용선(ingress/egress)이며, default deny 위에 필요한 통신만 연다. 이번 kindnet은 pod↔pod TCP를 실제 강제해서 traffic matrix가 그대로 재현됐다(frontend→api ✅ / frontend→postgres ❌ / unknown→api ❌ / api→postgres ✅). DNS egress는 CNI마다 처리가 달라 정책엔 넣는 게 정석.**

## 실습 확인 기록

### ① NetworkPolicy 8종 적용 — 역할별 허용선
```text
$ kubectl apply -f week4/day2/labs/traffic-routing/networkpolicy-preview.yaml
networkpolicy.networking.k8s.io/default-deny-all created
networkpolicy.networking.k8s.io/allow-dns-egress created
networkpolicy.networking.k8s.io/allow-frontend-to-api created
networkpolicy.networking.k8s.io/allow-frontend-egress-to-api created
networkpolicy.networking.k8s.io/allow-api-to-db created
networkpolicy.networking.k8s.io/allow-envoy-gateway-to-frontend created
networkpolicy.networking.k8s.io/allow-envoy-gateway-to-api created
networkpolicy.networking.k8s.io/allow-api-egress-to-db created

$ kubectl -n week4 get networkpolicy
NAME                              POD-SELECTOR   AGE
allow-api-egress-to-db            app=api        0s
allow-api-to-db                   app=postgres   0s
allow-dns-egress                  <none>         0s
allow-envoy-gateway-to-api        app=api        0s
allow-envoy-gateway-to-frontend   app=frontend   0s
allow-frontend-egress-to-api      app=frontend   0s
allow-frontend-to-api             app=api        0s
default-deny-all                  <none>         0s
```
- 읽는 포인트:
  - ⭐ `default-deny-all`·`allow-dns-egress`는 `POD-SELECTOR <none>`(=`{}`, 전체 Pod). 그 위에 역할별 허용을 얹음.
  - ⭐ frontend→api 한 경로에 **egress(frontend) + ingress(api) 2개** = 양방향 다 열어야 통과 (default deny 위라서).
  - ⭐ envoy gateway용 ingress 2개(`allow-envoy-gateway-to-frontend`, `-to-api`)는 외부 진입점(envoy)이 backend에 닿게 해줌.

### ② selector 대상 label 확인 — 정책이 label 기반
```text
$ kubectl -n week4 get pod --show-labels
NAME                        READY   STATUS    RESTARTS      AGE   LABELS
api-7d5f896774-j7wmr        1/1     Running   1 (23m ago)   18h   app=api,pod-template-hash=7d5f896774,tier=api
api-7d5f896774-khdbb        1/1     Running   1 (23m ago)   18h   app=api,pod-template-hash=7d5f896774,tier=api
frontend-7d66f6d9cb-k24m5   1/1     Running   1 (23m ago)   18h   app=frontend,pod-template-hash=7d66f6d9cb,tier=web
frontend-7d66f6d9cb-zcv6s   1/1     Running   1 (23m ago)   18h   app=frontend,pod-template-hash=7d66f6d9cb,tier=web
postgres-5f945bcf7f-6xfmn   1/1     Running   1 (23m ago)   18h   app=postgres,pod-template-hash=5f945bcf7f,tier=db

$ kubectl -n kube-system get pod -l k8s-app=kube-dns --show-labels
NAME                       READY   STATUS    RESTARTS      AGE   LABELS
coredns-589f44dc88-pgdns   1/1     Running   1 (23m ago)   19h   k8s-app=kube-dns,pod-template-hash=589f44dc88
coredns-589f44dc88-vdtqv   1/1     Running   1 (23m ago)   19h   k8s-app=kube-dns,pod-template-hash=589f44dc88

$ kubectl -n envoy-gateway-system get pod --show-labels
NAME                                                      READY   STATUS    RESTARTS      AGE   LABELS
envoy-gateway-6c8699d485-8sjnr                            1/1     Running   2 (22m ago)   17h   app.kubernetes.io/instance=envoy-gateway,app.kubernetes.io/name=gateway-helm,control-plane=envoy-gateway,...
envoy-week4-paperclip-gateway-184e87dc-6b549fdc6c-c5fsk   2/2     Running   2 (23m ago)   17h   app.kubernetes.io/component=proxy,app.kubernetes.io/managed-by=envoy-gateway,app.kubernetes.io/name=envoy,gateway.envoyproxy.io/owning-gateway-name=paperclip-gateway,...
```
- 읽는 포인트:
  - ⭐ policy selector(`app=api`/`app=frontend`/`app=postgres`)가 이 Pod label과 맞아야 적용됨. label = 정책의 API.
  - `allow-dns-egress`가 대상으로 삼는 CoreDNS Pod label이 **`k8s-app=kube-dns`** → 정책의 `namespaceSelector: kube-system` + `podSelector: k8s-app=kube-dns`와 일치.
  - `allow-envoy-gateway-*`가 노리는 데이터플레인 Pod는 **`app.kubernetes.io/name=envoy`**(`envoy-week4-...` proxy) → controller(`app.kubernetes.io/name=gateway-helm`)가 아니라 **proxy** label과 맞아야 실제 traffic이 열림.

### ③-a 적용 후 traffic — kindnet이 실제 강제함 (traffic matrix 재현)
```text
# [A] label 없는 Pod → api (정책상 허용 안 됨) — 차단되어 timeout 이어야 함
$ kubectl -n week4 run curlbox --rm -i --restart=Never --image=curlimages/curl:8.10.1 --command -- \
    sh -c 'curl -s -o /dev/null -w "http=%{http_code} tconnect=%{time_connect}\n" --max-time 5 http://api/api; echo "exit=$?"'
http=000 tconnect=0.000000
exit=28

# [C] label app=frontend Pod → api (허용 경로) — 200 이어야 함
$ kubectl -n week4 run fe-test --labels="app=frontend" --rm -i --restart=Never --image=curlimages/curl:8.10.1 --command -- \
    sh -c 'curl -s -o /dev/null -w "http=%{http_code} tconnect=%{time_connect}\n" --max-time 5 http://api/api; echo "exit=$?"'
http=200 tconnect=1.041220
exit=0

# [D] label app=frontend Pod → postgres:5432 (db 직접 금지) — 차단되어 timeout 이어야 함
$ kubectl -n week4 run fe-test2 --labels="app=frontend" --rm -i --restart=Never --image=curlimages/curl:8.10.1 --command -- \
    sh -c 'curl -s -o /dev/null -w "tconnect=%{time_connect}\n" --max-time 5 http://postgres:5432; echo "exit=$?"'
tconnect=0.000000
exit=28

# [E] label app=api Pod → postgres:5432 (api→db 허용) — TCP 연결되어야 함
$ kubectl -n week4 run api-test --labels="app=api" --rm -i --restart=Never --image=curlimages/curl:8.10.1 --command -- \
    sh -c 'curl -s -o /dev/null -w "tconnect=%{time_connect}\n" --max-time 5 http://postgres:5432; echo "exit=$?"'
tconnect=1.020258
exit=52
```
- 읽는 포인트:
  - ⭐ traffic matrix가 **그대로 재현됨**: [A] unknown→api ❌(exit=28 timeout), [C] frontend→api ✅(http=200), [D] frontend→postgres ❌(exit=28 timeout), [E] api→postgres ✅(tconnect 성공).
  - ⚠️ [E]의 `exit=52`는 차단이 아니라 **postgres가 HTTP가 아니라서 빈 응답**(curl "empty reply"). `tconnect=1.02`로 **TCP는 붙었음** → 허용된 게 맞음. 차단([A][D])은 `tconnect=0.000000 exit=28`(연결 자체가 안 됨)로 구분.
  - ⭐ 즉 label 없는/엉뚱한 label Pod는 default-deny에 걸려 못 가고, **정책이 허용한 label을 단 Pod만** 통과. label = 정책의 실제 스위치.

### ③-b DNS egress를 지워도 이번 kindnet에선 이름 해석 유지 (CNI 차이)
```text
$ kubectl -n week4 delete networkpolicy allow-dns-egress
networkpolicy.networking.k8s.io "allow-dns-egress" deleted from week4 namespace

# DNS egress 없이 frontend→api — 엄격한 CNI라면 "Could not resolve host" 나야 하지만…
$ kubectl -n week4 run dns-test --labels="app=frontend" --rm -i --restart=Never --image=curlimages/curl:8.10.1 --command -- \
    sh -c 'curl -sS -o /dev/null -w "http=%{http_code} tns=%{time_namelookup} tconnect=%{time_connect}\n" --max-time 6 http://api/api; echo "exit=$?"'
http=200 tns=0.000376 tconnect=1.043881
exit=0

$ kubectl apply -f week4/day2/labs/traffic-routing/networkpolicy-preview.yaml   # 복구
networkpolicy.networking.k8s.io/allow-dns-egress created
```
- 읽는 포인트:
  - ⚠️ pod↔pod TCP는 강제하던 kindnet인데, **`allow-dns-egress`를 지워도 DNS(53)는 계속 나갔다**(tns=0.000376, http=200). 이 CNI는 DNS egress를 매트릭스처럼 엄격히 막지 않음.
  - ⭐ 그래도 정책엔 **DNS egress를 넣는 게 정석** — Cilium/Calico 같은 엄격한 CNI에서는 지우면 즉시 `Could not resolve host`로 깨진다. "이번엔 안 깨졌다"를 "필요 없다"로 오해 금지.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| NetworkPolicy와 Service의 차이? | Service=어디로 보낼지(라우팅), NetworkPolicy=누가 누구에게 갈 수 있나(허용선) |
| ingress와 egress 차이? | ingress=Pod로 들어오는 traffic(destination에 검), egress=Pod에서 나가는 traffic(source에 검) |
| frontend→api를 열려면 policy 몇 개? | 2개. frontend egress + api ingress (default deny 위라 양쪽) |
| 이번에 policy가 6개가 아니라 8개인 이유? | envoy gateway→frontend, →api ingress 2개 추가 (외부 진입점이 backend에 닿게) |
| envoy gateway 허용에 뭐가 필요? | 다른 namespace라서 namespaceSelector(envoy-gateway-system)+podSelector(app.kubernetes.io/name=envoy) 교차 |
| namespace가 다르면 자동 차단? | 아님. 정책/CNI가 없으면 다른 namespace Service도 DNS로 호출됨 |
| NetworkPolicy port 기준은? | Pod가 실제 받는 port(frontend 80, api 8080, db 5432). Service port 아님 |
| 이번 kindnet에서 정책이 강제되나? | 됨. pod↔pod TCP 경로를 실제 차단(traffic matrix 재현). 단 DNS egress는 안 막음 |
| 허용/차단을 curl로 어떻게 구분? | 차단=tconnect 0 & exit 28(timeout). 허용=tconnect>0(200 또는 empty-reply exit 52) |
| Service 정상인데 timeout이면? | NetworkPolicy/CNI에서 packet drop 가능 → Hubble 등으로 flow 확인 |

## notes

### Evidence Note
```markdown
# W4D2S6 NetworkPolicy (kindnet v20260528, enforcement ON)
- policy 8종: default-deny-all, allow-dns-egress, allow-frontend-to-api(+egress), allow-api-to-db(+egress), allow-envoy-gateway-to-frontend, allow-envoy-gateway-to-api
- traffic matrix 재현됨:
  - unknown Pod -> api : DENY (tconnect=0, exit=28)
  - app=frontend -> api : ALLOW (http=200, tconnect=1.04)
  - app=frontend -> postgres:5432 : DENY (tconnect=0, exit=28)
  - app=api -> postgres:5432 : ALLOW (tconnect=1.02, exit=52 empty-reply=HTTP아님)
- 허용/차단 판별: tconnect==0 & exit28 = 차단 / tconnect>0 = 통과
- DNS egress 관찰: allow-dns-egress 삭제해도 이 kindnet은 이름 해석 유지(tns=0.0004) → 정책엔 넣되 엄격 CNI(Cilium/Calico)에서만 삭제 시 깨짐
- envoy gateway 허용 대상 label: app.kubernetes.io/name=envoy (proxy). controller(gateway-helm) 아님
- port 기준: pod 실제 port (frontend 80, api 8080, db 5432)
```

### ingress/egress 한 통신에 둘 다 (오늘 핵심)
```text
frontend → api 를 열려면:
  frontend Pod: egress 허용 (나가기)   ← allow-frontend-egress-to-api
  api Pod:      ingress 허용 (받기)     ← allow-frontend-to-api
default deny 위에서는 둘 중 하나만 열면 여전히 막힘.
```

### 허용/차단을 curl 수치로 읽는 법
```text
차단(DENY):  tconnect=0.000000, exit=28  → TCP 연결 자체가 timeout
허용(ALLOW): tconnect>0                  → TCP는 붙음
   - HTTP backend(api)  : http=200, exit=0
   - non-HTTP backend(postgres) : exit=52(empty reply) 이지만 tconnect>0 이라 "연결은 됨"
```
- ⚠️ exit 코드만 보면 [E](허용, 52)와 진짜 오류를 헷갈릴 수 있음 → **tconnect로 연결 성립 여부를 봐야** 함.

### Gateway API vs NetworkPolicy 층 분리
```text
Gateway/HTTPRoute (라우팅, L7)  ── 어디로
NetworkPolicy (path 제한, L3/4) ── 갈 수 있나
```
- 둘 다 정상이어야 traffic 성공. envoy gateway ingress 정책을 빼면 Gateway는 Programmed여도 backend에서 drop → 502/timeout.

### ingress↔from, egress↔to (키워드 짝)
```text
ingress:  들어옴  →  from: (source, 누구로부터 받나)
egress:   나감    →  to:   (destination, 어디로 보내나)
```
- ⚠️ 방향(ingress/egress)과 붙는 키워드가 **엇갈림**: ingress에는 `from:`, egress에는 `to:`. "ingress=to"로 외우면 뒤집힘.
- ⭐ 한 통신(frontend→api)을 열려면 **짝으로**: source의 egress(`to: api`) + destination의 ingress(`from: frontend`). default-deny 위라 한쪽만 열면 여전히 막힘.
  - `allow-frontend-egress-to-api`: `egress` + `to: app=api`
  - `allow-frontend-to-api`:        `ingress` + `from: app=frontend`

### policy 파일 분리 컨벤션 — 정답 없음(팀 규칙)
```text
① all-in-one   : 한 파일에 --- 로 전부 (지금 networkpolicy-preview.yaml, 8종)
② app별 분리   : frontend-netpol.yaml / api-netpol.yaml ...  (소유권 명확)
③ 방향별 분리  : ingress-policies.yaml / egress-policies.yaml (방향별 리뷰)
```
- ⭐ 정해진 규칙 없음. 규모 커지면 보통 **default-deny는 공통 baseline 파일**로 빼고 allow는 app별로 쪼개는 조합을 많이 씀.

### default-deny-all = baseline (먼저 잠그고 문 열기)
```text
$ kubectl -n week4 describe networkpolicy default-deny-all
Name:         default-deny-all
Namespace:    week4
Created on:   2026-07-02 09:39:09 +0900 KST
Labels:       <none>
Annotations:  <none>
Spec:
  PodSelector:     <none> (Allowing the specific traffic to all pods in this namespace)
  Allowing ingress traffic:
    <none> (Selected pods are isolated for ingress connectivity)
  Allowing egress traffic:
    <none> (Selected pods are isolated for egress connectivity)
  Policy Types: Ingress, Egress
```
- ⭐ NetworkPolicy는 **allowlist** → allow 규칙이 비면 곧 deny. `PodSelector: <none>`(전체) + allow 없음 = namespace 전부 차단.
- ⭐ 정석 순서: **default-deny 먼저(baseline) → 필요한 allow만 위에 얹기.** ③-a에서 unknown Pod가 timeout난 게 이 default-deny 때문.
- ⚠️ default-deny는 DNS(53)까지 막으므로 `allow-dns-egress`를 baseline 짝으로 같이 둠(엄격한 CNI 기준).

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| doc는 "6종"인데 yaml엔 8종 | envoy-gateway→frontend/api ingress 2개가 추가돼 있었음. matrix/manifest 표를 8종으로 갱신 |
| doc는 "kind는 강제 안 함(설계만)"이라 했는데 실제로 차단됨 | 이 cluster CNI = kindnet **v20260528**, NetworkPolicy enforcement 내장. unknown→api, frontend→postgres가 exit=28로 timeout → 실제 차단 확인 |
| `allow-dns-egress` 삭제했는데 이름 해석이 안 깨짐 | 이 kindnet은 DNS egress를 매트릭스처럼 막지 않음(tns=0.0004로 해석됨). 엄격 CNI에서만 삭제 시 깨진다고 정정 |
| curl [E] api→postgres가 exit=52 | 차단 아님. postgres가 HTTP 아니라 empty reply. tconnect=1.02로 TCP는 연결됨 = 허용 정상 |
