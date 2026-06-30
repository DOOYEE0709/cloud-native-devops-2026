# 6교시: Service와 내부 DNS

## 핵심 정리

### 왜 Service가 필요한가 — Pod IP는 안정적인 계약이 아니다
- Deployment가 Pod를 재생성하면 **Pod IP가 바뀐다.**
```text
Pod A: 10.244.0.12  →  (삭제/재생성)  →  Pod B: 10.244.0.18
```
- client가 Pod IP를 직접 알면 재생성마다 연결이 깨짐. **Service**가 바뀌는 Pod IP 뒤에 **안정적인 접근 지점**을 제공.
```text
client → http://hello-web → Service hello-web → endpoints → Ready Pods
```

### Service manifest
```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-web
  namespace: week3
spec:
  type: ClusterIP
  selector:
    app: hello-web        # 연결할 Pod label
  ports:
    - name: http
      port: 80            # Service가 받을 port
      targetPort: 80      # Pod/container로 보낼 port
```

| 필드 | 의미 |
|---|---|
| `type: ClusterIP` | cluster 내부에서 접근 가능한 가상 IP |
| `selector.app` | 연결할 Pod label |
| `port` | Service가 받을 port |
| `targetPort` | Pod/container 쪽으로 보낼 port |

### ⭐ DNS 성공 ≠ 통신 성공 (단계를 분리해서 보기)
- DNS는 **Service 이름을 찾는** 단계, 실제 traffic은 **selector가 만든 endpoint**로 전달된다.

| 항목 | 확인 명령 | 해석 기준 |
|---|---|---|
| Service DNS | `... nslookup hello-web` | 같은 namespace면 `hello-web`로 해석돼야 |
| ClusterIP | `get svc hello-web` | Pod IP와 달리 Service 사는 동안 안정적 |
| selector | `get svc hello-web -o jsonpath='{.spec.selector}'` | Pod label과 정확히 맞아야 endpoint 생김 |
| Pod label | `get pods --show-labels` | selector가 찾는 label이 Pod에 있어야 |
| Endpoints | `get endpoints hello-web` | Ready Pod IP:port가 보여야 |
| EndpointSlice | `get endpointslice -l kubernetes.io/service-name=hello-web` | 최신 k8s는 EndpointSlice로 더 세밀하게 관리 |

**증상별 분기**:
```text
DNS 성공 + endpoint 없음 = 이름은 찾았지만 보낼 Pod가 없음 (selector/label 확인)
DNS 실패            = Service 이름·namespace·CoreDNS 상태부터 확인
endpoint 있음 + curl 실패 = Pod readiness·container port·app 응답·NetworkPolicy 확인
```

### Service 생성 & selector→label→endpoint 한 줄로 잇기 (명령)
```bash
export NS=week3
export LAB=week3/day5/labs/k8s-first-app
kubectl apply -f "$LAB/service.yaml"
kubectl -n "$NS" get svc hello-web -o wide
kubectl -n "$NS" get pods -l app=hello-web --show-labels -o wide
kubectl -n "$NS" get endpoints hello-web
```
- 성공 기준: **TYPE=ClusterIP**, **Endpoints에 Pod IP:80이 2개**.

### Service DNS 확인 (curlbox로 내부에서) (명령)
```bash
kubectl -n "$NS" run curlbox --rm -it --image=curlimages/curl:8.8.0 --restart=Never -- \
  curl -sI http://hello-web
```
- 성공 패턴: `HTTP/1.1 200 OK` / `Server: nginx`.

| DNS 이름 | 설명 |
|---|---|
| `hello-web` | 같은 namespace 안 짧은 이름 |
| `hello-web.week3` | namespace 포함 |
| `hello-web.week3.svc.cluster.local` | 전체 cluster DNS 이름 (FQDN) |

### ⚠️ selector 장애 만들기 → endpoint 비는 패턴 (명령)
```bash
# selector를 일부러 틀린 label로
kubectl -n "$NS" patch service hello-web -p '{"spec":{"selector":{"app":"wrong-label"}}}'
kubectl -n "$NS" get endpoints hello-web        # → ENDPOINTS 비어 있음

# 원인 비교: Service가 찾는 selector vs Pod의 실제 label
kubectl -n "$NS" get svc hello-web -o jsonpath='{.spec.selector}{"\n"}'
kubectl -n "$NS" get pods --show-labels

# 복구
kubectl apply -f "$LAB/service.yaml"
kubectl -n "$NS" get endpoints hello-web
```
- ⚠️ **Pod는 Running인데 endpoint만 비어 있으면** = backend가 죽은 게 아니라 **`selector`와 `label` 계약이 깨진 것.** 운영에서 자주 나오는 유형. app 장애처럼 보이지만 실제는 label 불일치.

### Week4 Ingress와의 연결
```text
browser/curl → Ingress Controller → Ingress rule → Service → Endpoint → Pod
```
- Ingress는 **직접 Pod로 안 간다.** 보통 Service로 traffic을 보냄 → Service selector/endpoint를 못 읽으면 **Ingress 장애도 분석 어려움.**

### 한 줄 요약
> **Service는 Pod IP를 숨기고 selector로 Ready Pod endpoint를 찾아주는 안정적인 내부 접근점이다.**

## 실습 확인 기록

### ① Service 생성 → ClusterIP·endpoint 확인
```text
$ kubectl -n week3 apply -f $LAB/service.yaml
service/hello-web created

$ kubectl -n week3 get svc hello-web
NAME        TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
hello-web   ClusterIP   10.96.4.33   <none>        80/TCP    20s

$ kubectl -n week3 get endpoints hello-web
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME        ENDPOINTS                       AGE
hello-web   10.244.0.11:80,10.244.0.12:80   37s
```
- 읽는 포인트:
  - **TYPE=ClusterIP, CLUSTER-IP `10.96.4.33`** = cluster 내부 가상 IP. Pod IP(`10.244.x`)와 대역이 다름 — Service는 별도 service 대역(`10.96.x`)을 받는다.
  - **EXTERNAL-IP `<none>`** = 외부 노출 안 됨(ClusterIP라서). 외부 접근은 NodePort/LoadBalancer/Ingress 필요.
  - **ENDPOINTS에 Pod IP:80 2개**(`10.244.0.11:80`, `10.244.0.12:80`) → selector(`app=hello-web`)가 Ready Pod 2개를 잡았다는 증거. (Pod 개수와 일치)
  - ⚠️ **`v1 Endpoints is deprecated` 경고** = 무해. 최신 k8s는 EndpointSlice를 권장 → `get endpointslice -l kubernetes.io/service-name=hello-web`로도 같은 정보 확인 가능.

### ② DNS 조회 — Service 없을 때 (NXDOMAIN → 해석)
```text
# Service 만들기 전: 이름을 못 찾음
$ kubectl -n week3 run curlbox --rm -it --image=curlimages/curl:8.8.0 --restart=Never -- nslookup hello-web
Server:    10.96.0.10        ← CoreDNS(cluster DNS) 주소
** server can't find hello-web.week3.svc.cluster.local: NXDOMAIN   ← 그런 Service 없음
pod week3/curlbox terminated (Error)
```
- 읽는 포인트:
  - **NXDOMAIN = "그런 이름 없음".** DNS는 정상 동작했고, 조회 대상 Service가 **존재하지 않을** 뿐. (= service.yaml apply 전)
  - `10.96.0.10` = CoreDNS. 모든 Service 이름 해석은 여기로 감.
  - `terminated (Error)`는 nslookup이 "못 찾음"으로 비정상 종료코드를 낸 것 → **명령 실행은 정상**, 결과가 NXDOMAIN일 뿐.
  - `couldn't attach ... falling back to streaming logs` 경고도 무해 — Pod가 너무 빨리 끝나 attach 대신 로그를 스트리밍한 것.
  - → ①에서 Service를 만든 뒤 다시 조회하면 `hello-web.week3.svc.cluster.local`에 ClusterIP(`10.96.4.33`)가 찍힌다.

### ③ DNS 정상 해석 (Service 생성 후)
```text
$ kubectl -n week3 run curlbox --rm -it --image=curlimages/curl:8.8.0 --restart=Never -- nslookup hello-web
Server:    10.96.0.10
Address:   10.96.0.10:53

** server can't find hello-web.cluster.local: NXDOMAIN         ← search domain 순회 중 빗나간 것 (무시)
Name:   hello-web.week3.svc.cluster.local
Address: 10.96.4.33                                            ← ⭐ 정식 FQDN이 ClusterIP로 해석됨 (①의 10.96.4.33과 일치)
** server can't find hello-web.svc.cluster.local: NXDOMAIN     ← 역시 search domain 헛방 (무시)
```
- 읽는 포인트:
  - **`hello-web.week3.svc.cluster.local` → `10.96.4.33`** = ①에서 만든 Service ClusterIP로 정확히 해석. DNS 성공.
  - 중간의 NXDOMAIN들은 실패가 아님. resolver가 **search domain 목록**(`cluster.local`, `svc.cluster.local`, `week3.svc.cluster.local` …)을 차례로 붙여 보다가 맞는 것(`week3.svc.cluster.local`)에서 성공한 것. 안 맞는 후보는 NXDOMAIN으로 찍힐 뿐.
  - 그래서 **짧은 이름 `hello-web`이 같은 namespace에서 동작**하는 이유 = resolver가 `week3.svc.cluster.local`을 자동으로 붙여줘서.
  - ②(Service 없음, 전부 NXDOMAIN)와 비교하면 차이가 분명: 이번엔 **정답 한 줄(Address)이 있음.**

### ④ curl로 DNS+통신까지 한 번에 (HTTP 200)
```text
$ kubectl -n week3 run curlbox --rm -it --image=curlimages/curl:8.8.0 --restart=Never -- curl -sI http://hello-web
HTTP/1.1 200 OK                                  ← ⭐ 끝. DNS+endpoint+응답 전부 정상
Server: nginx/1.27.5
Content-Type: text/html
Content-Length: 615
```
- 읽는 포인트:
  - **`HTTP/1.1 200 OK` 한 줄이 6교시 최종 성공 신호.** 이 한 번에 **3단계가 다 통과**한 것:
    1. **DNS** — `hello-web` → ClusterIP(`10.96.4.33`) 해석 (③)
    2. **endpoint 전달** — ClusterIP가 Ready Pod IP:80으로 라우팅 (①의 endpoint 2개)
    3. **app 응답** — 그 Pod의 nginx가 실제로 200 응답
  - **`Server: nginx/1.27.5`** = 진짜 backend nginx가 답했다는 증거 (Service가 아니라 그 뒤 Pod).
  - nslookup(③)은 "이름만" 확인이라 NXDOMAIN 노이즈가 보였지만, **curl은 통신까지** 보므로 200이면 군더더기 없이 깔끔. → 실무에선 **curl 한 방**이 더 확실한 검증.
  - 흐름 대조: ② DNS 실패(Service 없음) → ③ DNS 성공(이름→IP) → ④ 통신 성공(IP→Pod→200). **단계가 한 칸씩 올라간 것.**

### ⑤ ⚠️ selector 장애 — Pod는 멀쩡한데 endpoint만 빔
```text
$ kubectl -n week3 patch service hello-web -p '{"spec":{"selector":{"app":"wrong-label"}}}'
service/hello-web patched

$ kubectl -n week3 get endpoints hello-web
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME        ENDPOINTS   AGE
hello-web   <none>      7m36s        ← ⚠️ 비었음 (①에선 Pod IP:80 2개였는데)
```
- 읽는 포인트:
  - selector를 `app=wrong-label`로 바꾸자 **endpoint가 `<none>`**. ①의 `10.244.0.11:80,10.244.0.12:80`이 사라짐.
  - ⚠️ **Pod는 그대로 Running, Deployment도 정상.** 죽은 게 없는데 통신만 끊김 → 이게 운영에서 헷갈리는 패턴.
  - 원인: Service가 찾는 selector(`app=wrong-label`)와 Pod의 실제 label(`app=hello-web`)이 **안 맞아** 매칭되는 Pod가 0개.
  - 이 상태에서 `curl http://hello-web`은 실패(혹은 timeout) — DNS는 되는데(③) **보낼 endpoint가 없어서**. (핵심 정리 "DNS 성공 ≠ 통신 성공"의 실증)

원인 진단 (Pod는 멀쩡 + Service만 못 찾음):
```text
$ kubectl -n week3 get pods -l app=hello-web
NAME                         READY   STATUS    RESTARTS   AGE
hello-web-74d95c87c8-9hwmq   1/1     Running   0          45m      ← Pod는 둘 다 정상 Running
hello-web-74d95c87c8-d9xv8   1/1     Running   0          45m

$ kubectl -n week3 describe svc hello-web
Selector:    app=wrong-label        ← Service가 찾는 label (틀림)
Endpoints:                          ← 비어 있음 = 매칭 Pod 0개
IP:          10.96.4.33             ← ClusterIP는 그대로 (Service 자체는 살아있음)

# 진단 공식: Service가 찾는 selector  vs  Pod에 실제 붙은 label
$ kubectl -n week3 get svc hello-web -o jsonpath='{.spec.selector}{"\n"}'
{"app":"wrong-label"}                                          ← Service가 찾는 것

$ kubectl -n week3 get pods --show-labels
hello-web-74d95c87c8-9hwmq ... app=hello-web,...,tier=web      ← Pod의 실제 label
hello-web-74d95c87c8-d9xv8 ... app=hello-web,...,tier=web      ← app=wrong-label과 안 맞음 = 원인 확정
```
- 읽는 포인트:
  - **Pod READY `1/1 Running` × 2** = backend는 완전히 정상. 그런데 **`Endpoints:` 비었고 `Selector: app=wrong-label`**.
  - **진단 공식**: `get svc -o jsonpath='{.spec.selector}'`(Service가 **찾는** label) ↔ `get pods --show-labels`(Pod에 **붙은** label)를 나란히 비교 → `wrong-label` ≠ `hello-web` → 원인 확정.
  - ClusterIP(`10.96.4.33`)는 유지됨 → Service object 자체는 살아있고, **연결(endpoint)만** 끊긴 상태.

복구:
```bash
kubectl -n week3 apply -f $LAB/service.yaml          # selector를 app=hello-web으로 원복
kubectl -n week3 get endpoints hello-web              # Pod IP:80 2개 다시 보이면 복구 완료
```

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Service가 필요한 이유는? | Pod 재생성 시 IP가 바뀜. Service가 그 뒤에 안정적인 접근점(ClusterIP/DNS) 제공 |
| selector가 하는 일은? | Pod label과 매칭해 endpoint(보낼 Ready Pod)를 만든다 |
| port vs targetPort? | port=Service가 받는 포트, targetPort=Pod/container로 보내는 포트 |
| DNS 성공이면 통신 성공인가? | 아님. DNS는 이름 찾기 단계. endpoint가 비면 보낼 Pod가 없어 통신 실패 |
| Pod는 Running인데 endpoint가 빈 이유는? | Service selector와 Pod label 계약이 깨짐. app 장애 아님 |
| 짧은 이름 `hello-web`이 해석되는 조건은? | 같은 namespace 안. 다르면 `hello-web.week3` 또는 FQDN 필요 |

## notes

### Evidence Note
```markdown
# W3D5S6 Service
- Service name:
- ClusterIP:
- selector:
- endpoint count:
- curlbox result:
- selector 장애 시 endpoint:
- 복구 후 endpoint:
```

### curlbox는 일회용 디버그 Pod
- `kubectl run curlbox --rm -it --image=curlimages/curl ... --restart=Never`:
  - `--rm` = 끝나면 자동 삭제, `-it` = 인터랙티브, `--restart=Never` = Pod로 한 번만 실행(Deployment 아님).
- cluster **내부에서** Service DNS/통신을 테스트하려는 용도. nginx Pod에 curl이 없을 수도 있으니(2교시) 별도 curl image로 띄움.

### endpoint vs EndpointSlice
- `endpoints`(구버전 형식)와 `endpointslice`(최신, 더 세밀)는 같은 정보를 다른 형태로 보여줌.
- 장애 분석 땐 둘 중 편한 걸로 "Ready Pod IP:port가 실제로 잡혀 있나"를 확인.

### 왜 "Pod IP를 숨긴다"고 하나 (바뀜을 client로부터 격리)
- "숨긴다"와 "Pod IP가 계속 바뀐다"는 **같은 이유.** 바뀌는 IP를 client가 직접 보지 못하게 가리고, 안 바뀌는 주소를 주는 것.

```text
[숨기기 전] client → 10.244.0.11   ← Pod 재생성되면 IP 죽음 → client 깨짐 💥
[Service]   client → hello-web (10.96.4.33, 고정)
                          └→ 지금 살아있는 Pod IP(10.244.0.11/.12)로 전달
```

| | 바뀌나? | 누가 보나 |
|---|---|---|
| Pod IP (`10.244.x`) | ✅ 재생성마다 | Service만 (내부) |
| Service ClusterIP (`10.96.4.33`) | ❌ 고정 | client |
| Service 이름 (`hello-web`) | ❌ 고정 | client |

- Pod IP는 **여전히 바뀜.** 단 그 변화가 **Service 뒤에서만** 일어나고 client가 보는 주소는 안 바뀜 → 이게 "숨긴다".
- selector가 항상 "label 맞는 현재 Ready Pod"를 잡아 **endpoint를 실시간 갱신** → Pod가 죽고 새로 떠도 client는 변화를 못 느낌.
- 비유: 식당 **대표번호**(Service). 직원(Pod)·개인폰(Pod IP)은 계속 바뀌어도 손님은 대표번호 하나만 알면 됨.

> 한 줄: **숨긴다 = Pod IP의 바뀜을 client로부터 격리한다.** 바뀌는 것(Pod IP)을 안 바뀌는 것(Service) 뒤에 가둔다.

### Service는 프로세스가 아니라 "네트워크 규칙"이다
- Service는 node 안에서 도는 프로세스도, Pod도 아니다. ClusterIP를 듣는 서버가 **없다.** 실체는 **각 node에 깔린 네트워크 규칙(iptables/IPVS)**.

```text
ClusterIP 10.96.4.33 = 진짜 서버 ❌
                     = "이 IP로 오는 패킷은 지금 Ready인 Pod IP로 목적지를 바꿔라(DNAT)"는 규칙 ✅
```
- client가 `10.96.4.33:80`으로 보내면 → node 규칙이 가로채 **실제 Pod IP로 DNAT** 해서 전달.
- ClusterIP는 **어느 Pod의 것도 아닌 가상 IP(virtual IP)** → ping 안 되는 경우 많음(listener 없는 규칙이라).

| 구성요소 | 역할 |
|---|---|
| **Service** (object) | "원하는 상태" 선언 (etcd 저장). 추상화 |
| **kube-proxy** (각 node component) | Service/endpoint 보고 **node에 iptables/IPVS 규칙을 실제로 깐다** |
| **CoreDNS** (component) | Service 이름 → ClusterIP 해석 |
| **kubelet** | Pod 실행 |

- "Service가 component인가?" → **Service 자체는 API object(선언)**, 그걸 **실제로 구현하는 component는 kube-proxy(규칙) + CoreDNS(이름)**. 구분해서 본다.

> 한 줄: **Service = "selector 맞는 Pod로 보내라"는 네트워크 규칙(가상 IP). 그 규칙을 각 node에 까는 실제 component가 kube-proxy다.**

### Service 장애 진단 순서 — "트래픽 경로를 따라간다"
```text
client → Service(이름/ClusterIP) → endpoint(selector 매칭) → Pod
            ①                          ③                    ②
```

| 순서 | 확인 | 명령 | 본질 |
|---|---|---|---|
| ② | **Pod 살았나** | `get pods -l app=hello-web` | backend가 Running/Ready? (죽었으면 endpoint도 빔) |
| ① | **Service 살았나** | `describe svc` / `get svc` | 존재? ClusterIP 있나? **Endpoints 비었나?** |
| ③ | **label 맞나** | `get svc -o jsonpath='{.spec.selector}'` ↔ `get pods --show-labels` | selector = label 인가? |

- 판단 분기:
  - Pod가 죽음 → app/Pod 문제 (3교시 영역)
  - **Pod는 Running인데 endpoint 빔 → selector ↔ label 불일치** (③ 비교가 결정타)
  - endpoint 있는데 curl 실패 → readiness·container port·NetworkPolicy

> 한 줄: **Pod(backend) 살았나 → Service의 endpoint 찼나 → 비었으면 selector vs label 비교.** endpoint가 "찼나 비었나"가 갈림길.

### 리소스 생성 순서 — cluster → namespace → deployment → service
```text
1) kind create cluster        ← cluster(집)            [kind]
2) kubectl apply namespace    ← week3 namespace(방)    [kubectl]   ★ deployment보다 먼저
3) kubectl apply deployment   ← Pod/ReplicaSet(앱)     [kubectl]
4) kubectl apply service      ← Service(접근점)        [kubectl]
```

| 순서 | 만드는 것 | 왜 이 순서 |
|---|---|---|
| 1 | cluster | 없으면 `localhost:8080 connection refused` |
| 2 | **namespace** | 없으면 `namespaces "week3" not found` (방이 없어 못 넣음) |
| 3 | deployment | Pod에 `app=hello-web` label 붙음 |
| 4 | service | selector로 그 label 잡아 endpoint 만듦 |

- ⚠️ **namespace는 deployment에 묶인 게 아니라 그보다 먼저** 따로 만들어야 한다 (deployment/service가 `week3` 안에 들어가므로). "바깥 그릇부터 안쪽" 원칙.
- **3·4 사이 순서는 유연**: Service를 Pod보다 먼저 만들어도 됨 — Service는 만든 뒤 **label 맞는 Pod가 생기면 그때 endpoint를 자동으로 채움.** 학습 흐름상 deployment → service가 자연스러울 뿐.

> 한 줄: **cluster → namespace → deployment → service.** namespace는 deployment에 포함이 아니라 그 앞 단계.

### ⚠️ nslookup의 NXDOMAIN·Error는 "실패"가 아니다 (성공 판단 기준)
짧은 이름으로 nslookup하면 출력에 NXDOMAIN이 섞이고 Pod가 `terminated (Error)`로 끝나는데, **해석은 성공한 것일 수 있다.** 진짜 판단은 `Address:` 줄로 한다.

```text
Address: <ClusterIP> 줄이 있다  → DNS 성공 (NXDOMAIN·Error 섞여도 OK)
전부 NXDOMAIN, Address 없음     → 진짜 실패 (Service 미존재 등)
```

**왜 NXDOMAIN이 섞이나 (= 정상 동작)**: resolver가 짧은 이름에 **search domain을 차례로 붙여가며** 시도하기 때문.

| 시도한 이름 | 결과 |
|---|---|
| `hello-web.cluster.local` | NXDOMAIN ❌ (헛방) |
| `hello-web.svc.cluster.local` | NXDOMAIN ❌ (헛방) |
| **`hello-web.week3.svc.cluster.local`** | **Address 10.96.4.33 ✅** |

- 맞는 후보 하나에서 성공하면 끝. 안 맞는 후보의 NXDOMAIN은 **검색 과정**일 뿐.
- 짧은 이름 `hello-web`이 같은 namespace에서 되는 이유 = resolver가 `week3.svc.cluster.local`을 자동으로 붙여줘서.
- **`terminated (Error)`** = nslookup이 중간 NXDOMAIN으로 비정상 종료코드를 낸 것. **종료코드 ≠ 해석 실패.**

**노이즈 없이 보려면**:
```bash
# FQDN으로 직접 물으면 search domain 순회가 없어 NXDOMAIN 안 섞임
kubectl -n week3 run curlbox --rm -it --image=curlimages/curl:8.8.0 --restart=Never -- \
  nslookup hello-web.week3.svc.cluster.local

# 또는 DNS+통신까지 한 방에 (6교시 핵심)
kubectl -n week3 run curlbox --rm -it --image=curlimages/curl:8.8.0 --restart=Never -- \
  curl -sI http://hello-web        # HTTP/1.1 200 OK 나오면 끝
```

> 한 줄: **`Name:/Address:` 한 줄이 나오면 성공.** NXDOMAIN·Error는 search domain 순회와 종료코드 때문이지 해석 실패가 아니다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
