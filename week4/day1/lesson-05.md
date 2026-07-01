# 5교시: Probe와 Readiness

## 핵심 정리

### 세 가지 probe — 각자 다른 질문
| Probe | Kubernetes의 질문 | 실패 시 영향 |
|---|---|---|
| startupProbe | 시작이 끝났는가 | 성공 전까지 다른 probe 판단 지연 |
| readinessProbe | 지금 traffic을 받아도 되는가 | **Service endpoint에서 제외** |
| livenessProbe | 재시작해야 하는가 | **container restart** |

- ⭐ 이번 교시 한 문장: **readiness = traffic 기준**, **liveness = restart 기준**. 둘은 다른 질문이다.

### probe 방식 3가지
| 방식 | 예시 | 적합한 경우 |
|---|---|---|
| HTTP GET | `/ready`, `/healthz` | 웹/API 서버 (입문에 가장 쉬움) |
| TCP socket | port 연결 확인 | HTTP endpoint 없는 TCP 서비스 |
| exec | container 안 명령 실행 | 특정 파일/프로세스 확인 |

### ① 정상 probe Deployment
```bash
export NS=week4
export LAB=week4/day1/labs/workload-basics
kubectl apply -f "$LAB/deployment.yaml"
kubectl apply -f "$LAB/service.yaml"
kubectl -n "$NS" rollout status deploy/runtime-api
kubectl -n "$NS" get pod -l app=runtime-api        # 기대: 1/1 Running
```
- describe로 probe 설정 확인:
```text
Readiness:  http-get http://:http/ delay=3s timeout=2s period=5s
Liveness:   http-get http://:http/ delay=10s timeout=2s period=10s
```

### ② readiness 실패 실험 — Running이지만 Ready 아님
> ⚠️ lab 수정: `http-echo:1.0`은 **모든 경로에 200**을 줘서 `path=/not-ready`로는 실패를 못 만듦. 그래서 probe를 **안 듣는 포트(8081)** 로 보내 확실히 실패시킴 (http-echo는 8080만 listen). 실패 메시지는 404가 아니라 **connection refused**.
```bash
kubectl apply -f "$LAB/deployment-bad-readiness.yaml"   # probe port=8081 (아무도 안 들음)
kubectl -n "$NS" get pod -l app=runtime-api-bad-readiness
kubectl -n "$NS" describe pod -l app=runtime-api-bad-readiness
```
- ⭐ **`READY 0/1` + `STATUS Running` + `RESTARTS 0`** = process는 살아있지만 traffic 받을 준비 안 됨. 그리고 **재시작은 안 함**.

| 컬럼 | 의미 |
|---|---|
| `READY 0/1` | container 1개 중 준비된 게 0개 |
| `STATUS Running` | process는 실행 중 (죽은 게 아님) |
| `RESTARTS 0` | readiness 실패는 **재시작을 유발 안 함** (liveness와 다름) |

- describe events 핵심 메시지:
```text
Warning  Unhealthy  80s (x25 over 3m18s)  kubelet  Readiness probe failed: Get "http://10.244.0.13:8081/": dial tcp 10.244.0.13:8081: connect: connection refused
```

| 부분 | 의미 |
|---|---|
| `Warning Unhealthy` | kubelet이 점검 실패 기록 |
| `Readiness probe failed` | traffic 준비 상태 실패 |
| `connection refused` | probe port(8081)에 아무도 안 들음 |
| `x25 over 3m18s` | period=5s로 계속 재시도 중 (성공 안 함) |

### ③ readiness와 Service endpoint 연결
```bash
kubectl -n "$NS" get svc,endpoints
kubectl -n "$NS" describe endpoints runtime-api
```
- ⭐ **readiness 실패 Pod는 Service endpoint에서 빠진다.** 그래서 `get pod`만 보면 부족.
```text
정상:  runtime-api   10.244.0.12:8080,10.244.0.13:8080
전부 실패:  runtime-api   <none>
```
- endpoint가 `<none>`이면 Service DNS는 resolve되지만 backend가 없어 **503 / connection reset / timeout** 계열 오류.

### ④ curl로 사용자 관점 확인
```bash
kubectl -n "$NS" run curlbox --rm -it --restart=Never \
  --image=curlimages/curl:8.10.1 \
  -- curl -s -o /dev/null -w "%{http_code}\n" http://runtime-api
```
- 정상: `200`. endpoint 비면: `curl: (7) Failed to connect to runtime-api port 80` (또는 Ingress 경유 시 503).

### probe 설계 실수 & 조정 기준
| 실수 | 결과 |
|---|---|
| `/`만 확인 | 앱은 떠 있지만 DB 연결 실패를 못 잡음 |
| readiness=liveness 같은 endpoint | 일시적 dependency 장애가 **restart 폭탄**으로 번짐 |
| initialDelay 너무 짧음 | 느린 앱이 시작 중 계속 실패 |
| timeout 너무 짧음 | 부하 순간에 false negative |
| liveness 너무 공격적 | 복구보다 restart가 더 큰 장애 |

| 필드 | 의미 | 너무 작을 때 |
|---|---|---|
| `initialDelaySeconds` | 첫 probe 전 대기 | 시작 중 실패 |
| `periodSeconds` | probe 주기 | 불필요한 probe 증가 |
| `timeoutSeconds` | 응답 대기 | 순간 지연을 장애로 오판 |
| `failureThreshold` | 몇 번 실패해야 실패 처리 | false positive 증가 |

### ⚠️ readiness와 liveness를 같은 endpoint로 쓰면 위험
```text
DB 지연 → /health 실패 → liveness 실패 → container restart
  → cold start → 다시 DB 연결 지연 → restart 반복 (restart 폭탄)
```
- 원래 30초 dependency 지연이 공격적 liveness 때문에 **더 큰 장애**가 됨.
- 원칙: readiness는 "**요청 받을 준비**", liveness는 "**재시작 필요한 고착 상태**" — 다른 질문으로.

### 오늘의 판단 루프
```text
kubectl get pod        → READY 0인지
kubectl describe pod   → probe 실패 reason
kubectl get endpoints  → Service가 보낼 대상 있는지
kubectl logs           → app 내부 오류
manifest 수정 → rollout
```

### 한 줄 요약
> **readiness는 traffic 기준(endpoint 제외), liveness는 restart 기준. probe는 빨리 죽이는 장치가 아니라 상태를 정확히 판단하는 장치다.**

## 실습 확인 기록

### ① 정상 probe — 1/1 Running + probe 설정
```text
$ kubectl -n week4 rollout status deploy/runtime-api
deployment "runtime-api" successfully rolled out

$ kubectl -n week4 get pod -l app=runtime-api
NAME                           READY   STATUS    RESTARTS   AGE
runtime-api-78975fb9df-8sl6l   1/1     Running   0          40m
runtime-api-78975fb9df-n22w2   1/1     Running   0          40m

$ kubectl -n week4 describe pod <pod>
...
    Ready:          True
    Restart Count:  0
    Liveness:   http-get http://:http/ delay=10s timeout=2s period=10s #success=1 #failure=3
    Readiness:  http-get http://:http/ delay=3s timeout=2s period=5s #success=1 #failure=3
Conditions:
  Type              Status
  Ready             True       ← Pod 전체가 traffic 받을 준비됨
  ContainersReady   True
```
- 읽는 포인트:
  - **`READY 1/1` + `Conditions: Ready True`** = readiness 통과 → Service endpoint에 포함됨.
  - readiness는 `delay=3s`로 빨리, liveness는 `delay=10s`로 늦게 시작 → 시작 직후 liveness가 오판해 재시작하는 걸 방지.
  - `#success=1 #failure=3` = readiness는 1번 성공하면 Ready, liveness는 3번 연속 실패해야 restart → **liveness가 더 관대**하게 잡혀 성급한 재시작을 막음.
  - `Annotations: restartedAt` = ④의 `rollout restart`가 남긴 흔적 (이 Pod가 재시작으로 새로 뜬 것). `Restart Count: 0`은 뜬 뒤로 컨테이너가 죽은 적 없다는 뜻 (둘은 다른 개념).

### ② readiness 실패 — Running인데 0/1 (+ rolling update 안전장치)
```text
$ kubectl -n week4 get pod -l app=runtime-api-bad-readiness
NAME                                         READY   STATUS    RESTARTS   AGE
runtime-api-bad-readiness-6b87897bdd-99kr5   0/1     Running   0          3m21s   ← 새 Pod (probe 8081, 실패)
runtime-api-bad-readiness-86d947c98c-h52sc   1/1     Running   0          13m     ← 옛 Pod (안 죽고 살아있음)

$ kubectl -n week4 describe pod runtime-api-bad-readiness-6b87897bdd-99kr5
...
    Ready:          False
    Restart Count:  0
    Readiness:    http-get http://:8081/ delay=3s timeout=2s period=5s #success=1 #failure=2
Conditions:
  Type              Status
  Ready             False       ← Pod가 traffic 준비 안 됨
  ContainersReady   False
Events:
  Warning  Unhealthy  80s (x25 over 3m18s)  kubelet  Readiness probe failed: Get "http://10.244.0.13:8081/": dial tcp 10.244.0.13:8081: connect: connection refused
```
- 읽는 포인트:
  - ⭐ **`0/1 Running` + `RESTARTS 0` + `Ready: False`** = 앱 process는 살아있는데(`Running`) traffic 준비 안 됨(`0/1`), 그리고 **재시작 안 함**. "Pod 떴는데 왜 안 돼요?"의 전형이자 readiness의 정의 그대로.
  - **`connection refused`** = probe가 8081로 갔는데 http-echo는 8080만 listen → 연결 거부. `x25 over 3m18s` = period=5s로 계속 재시도 중.
  - ⭐ **Pod가 2개** = rollout이 옛 Pod(`86d...` 1/1)를 안 죽이고 남겨둠! 새 Pod가 **Ready가 안 되니** 옛 Pod를 지우지 못함 → `rollout status`가 `1 old replicas are pending termination`으로 멈추고 timeout난 이유. **rolling update가 무중단을 지키는 안전장치** (Ready 안 된 새 버전으로 서비스가 넘어가지 않음).
  - 옛 Pod의 probe는 아직 `http://:http/not-ready`(200 통과라 `1/1`), 새 Pod만 `:8081`(실패) → template 바뀐 새 RS만 실패 상태.

### ③ endpoint — Service가 보낼 대상 (Ready Pod만)
```text
$ kubectl -n week4 get svc,endpoints
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME                  TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/runtime-api   ClusterIP   10.96.10.224   <none>        80/TCP    19h

NAME                    ENDPOINTS                           AGE
endpoints/runtime-api   10.244.0.10:8080,10.244.0.11:8080   19h

$ kubectl -n week4 describe endpoints runtime-api
Subsets:
  Addresses:          10.244.0.10,10.244.0.11    ← Ready Pod (traffic 받음)
  NotReadyAddresses:  <none>                     ← 준비 안 된 Pod (지금은 없음)
  Ports:
    Name  Port  Protocol
    http  8080  TCP
```
- 읽는 포인트:
  - ⭐ **endpoint에 Ready Pod 2개(IP `10.244.0.10`, `10.244.0.11`)만 등록** = ①의 `runtime-api` Pod들. readiness 통과 → Service가 여기로 traffic 분배.
  - **Service port `80` → target `8080`**: 사용자는 `:80`으로 접근, endpoint는 Pod의 실제 `:8080`. Service가 포트를 매핑함.
  - **`NotReadyAddresses: <none>`** = 지금 준비 안 된 Pod 없음. bad-readiness Pod(`0/1`)는 label이 `app=runtime-api-bad-readiness`라 이 Service selector(`app=runtime-api`)에 안 걸림 → 애초에 이 endpoint 후보가 아님.
  - 💡 만약 bad-readiness Pod가 **같은 Service 뒤에 있었다면** → `NotReadyAddresses`로 빠져서 traffic을 안 받음. 이게 "readiness가 라우팅을 제어한다"의 실물.
  - `Warning: v1 Endpoints is deprecated ... use EndpointSlice` = 요즘은 endpoint를 **EndpointSlice**로 관리 (대규모 확장성). `get endpoints`는 여전히 되지만 내부적으론 EndpointSlice가 원본.

### ④ curl — 사용자 관점 최종 확인
```text
$ kubectl -n week4 run curlbox --rm -it --restart=Never \
    --image=curlimages/curl:8.10.1 \
    -- curl -s -o /dev/null -w "%{http_code}\n" http://runtime-api
warning: couldn't attach to pod/curlbox, falling back to streaming logs: ...
200
pod "curlbox" deleted from week4 namespace
```
- 읽는 포인트:
  - ⭐ **`200`** = ③ endpoint에 등록된 Ready Pod(`10.244.0.10/.11`)가 실제로 요청을 받아 응답. endpoint→curl이 이어짐을 증명.
  - 만약 Ready Pod가 하나도 없어 endpoint가 `<none>`이면 → `curl: (7) Failed to connect to runtime-api port 80` (DNS는 풀리지만 보낼 대상이 없음).
  - `-o /dev/null -w "%{http_code}\n"` = 본문은 버리고 **HTTP 상태코드만** 출력 → Ready 여부를 숫자 하나로 확인.
  - 판단 루프의 끝: get pod(READY) → describe(reason) → endpoints(대상) → **curl(사용자 체감 200)** 까지 한 줄로 이어짐.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| readiness와 liveness의 차이? | readiness=traffic 받을 준비(실패 시 endpoint 제외), liveness=재시작 필요 판단(실패 시 restart) |
| startupProbe는 왜 있나? | 느린 시작 앱에서 시작 완료 전까지 다른 probe 판단을 지연시켜 조기 restart 방지 |
| `0/1 Running`의 의미? | process는 실행 중이지만 readiness 미통과 → traffic 준비 안 됨. 앱이 죽은 게 아님 |
| readiness 실패 Pod는 RESTARTS가 왜 0? | readiness는 재시작을 유발하지 않음. restart는 liveness의 몫 |
| readiness 실패가 Service에 미치는 영향? | 해당 Pod가 endpoint에서 빠짐 → Service가 그 Pod로 traffic 안 보냄 |
| readiness와 liveness를 같은 endpoint로 쓰면? | dependency 지연이 restart 폭탄으로 번져 더 큰 장애. 질문을 분리해야 함 |
| "Pod는 Running인데 왜 안 돼요?" 판단 순서? | get pod(READY) → describe(reason) → get endpoints(대상) → logs(내부오류) → 수정/rollout |

## notes

### Evidence Note
```markdown
# W4D1S5 Probe
- 정상 Pod READY:
- bad readiness Pod READY/STATUS:
- readiness 실패 메시지:
- endpoint 변화:
- readiness와 liveness를 분리해야 하는 이유:
```

### probe는 "빨리 죽이는 장치"가 아니다
- `failureThreshold`·`timeoutSeconds`를 너무 공격적으로 잡으면 순간 지연을 장애로 오판(false positive) → 멀쩡한 Pod가 endpoint에서 빠지거나 restart됨.
- probe의 목적은 **상태를 정확히 판단**하는 것. 4교시 "표면 출력을 성공으로 착각 안 하기"와 같은 결.

### 누가 죽이고 살리나 — readiness vs liveness (헷갈림 정리)
| | readinessProbe | livenessProbe |
|---|---|---|
| 질문 | "지금 traffic 받아도 돼?" | "재시작해야 해?" |
| 실패하면 | Service endpoint에서 **뺌** (traffic 차단) | container **restart** |
| Pod를 죽이나? | ❌ 안 죽임 (Running 유지, `0/1`) | ✅ 죽이고 다시 띄움 |
| RESTARTS 증가? | ❌ 안 늘어남 | ✅ 늘어남 |

- ⭐ **readiness = 죽이고 살리는 데 관여 안 함.** 실패해도 process는 그대로, traffic만 안 받음.
- **liveness = 재시작 담당.** 실패하면 container를 restart.
- 비유: readiness = 식당 "준비중" 팻말(가게 안 부숨) / liveness = "뻗었네" → 문 닫고 재오픈.
- 그래서 readiness 실패 Pod는 **`0/1 Running` + `RESTARTS 0`** 조합이 나옴 (②의 핵심).

### readiness가 라우팅을 제어한다는 감각
```text
Pod Ready       → endpoint 등록 → Service traffic 받음
Pod NotReady    → endpoint 제외 → traffic 안 받음 (process는 살아있음)
```
- W4D2 ingress-nginx에서 외부 traffic 진입점을 붙일 때, 이 readiness→endpoint 연결이 그대로 확장됨.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
