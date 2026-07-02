# 7교시: Rollout과 External Traffic

## 핵심 정리

### External traffic 경로 — 외부 요청이 Pod까지
```text
외부 client
  → Gateway (envoy proxy Service, :80)        어디로 들어오나 (진입점)
  → HTTPRoute (hostname + path 매칭)           어느 backend로 (라우팅 규칙)
  → backend Service (api:80 / frontend:80)     ClusterIP
  → Pod (api:8080 / frontend:80)               실제 처리
```
- ⭐ 6교시 in-cluster curl(`http://api`)과 달리, 오늘은 **밖에서 Gateway를 통해** 들어옴. 라우팅 판단은 Gateway/HTTPRoute가 함.

### ⚠️ kind에서 Gateway `PROGRAMMED=False` — 고장이 아니다
```text
envoy proxy Service = LoadBalancer 타입 → kind엔 cloud LB 없음 → EXTERNAL-IP <pending>
  → Gateway 최상위 Programmed=False (Reason: AddressNotAssigned)
```
- ⭐ **Listener는 Programmed=True**(`Attached Routes: 1`). 라우팅 설정은 정상 → **주소만 안 붙은 것**. `PROGRAMMED=False`를 "라우팅 깨짐"으로 오해 금지.
- ⭐ 외부 IP 없이도 접근 방법: **NodePort**(`80:31772`) 또는 **port-forward**. 실클라우드면 LB가 EXTERNAL-IP를 붙여 해결(또는 metallb/cloud-provider-kind).

### hostname 기반 라우팅 — Host 헤더가 열쇠
| 요청 | 결과 |
|---|---|
| `Host: paperclip.local` + `/api` | api backend ✅ |
| `Host: paperclip.local` + `/` | frontend backend ✅ |
| Host 없음/불일치 | **404** (listener hostname 매칭 실패) |

- ⭐ Gateway listener·HTTPRoute의 `hostname: paperclip.local`과 요청 Host가 맞아야 라우팅. curl은 `-H "Host: paperclip.local"`로 흉내.

### Rollout = RollingUpdate (무중단 교체)
```text
v1(2 Pod) --apply v2--> new Pod 1개 뜸(Ready 대기) → old 1개 종료 → 반복 → all v2
```
| 항목 | 값 | 의미 |
|---|---|---|
| strategy | RollingUpdate | 한 번에 다 안 바꾸고 점진 교체 |
| maxSurge | 25% | 초과 생성 허용 (2*25%→1개 더) |
| maxUnavailable | 25% | 동시에 죽여도 되는 수 (2*25%→1개) |

- ⭐ replicas 2 + 25% → **1개씩** 교체(`1 out of 2 new replicas...` → `1 old replicas are pending termination`). readinessProbe 통과한 new만 트래픽 받고 old 내림 → 무중단.
- ⭐ 교체는 **ReplicaSet 단위**: old RS scale 0, new RS scale 2. old RS가 0으로 남아 있어서 rollback 가능.

### rollout 관리 3종
```bash
kubectl -n week4 rollout status  deployment/api   # 진행 상황
kubectl -n week4 rollout history deployment/api   # revision 목록
kubectl -n week4 rollout undo    deployment/api   # 직전 revision 복귀
```
- ⚠️ `history`의 CHANGE-CAUSE가 `<none>`인 이유: `--record`나 annotation 없이 apply → 뭘 바꿨는지 기록 안 됨. revision 번호(1,2)는 남지만 이유는 안 남음.

### 한 줄 요약
> **External traffic은 외부→Gateway→HTTPRoute(hostname/path)→Service→Pod로 흐르며, kind는 LB가 없어 Gateway가 PROGRAMMED=False여도(주소만 미할당) NodePort/port-forward로 접근된다. Rollout은 RollingUpdate로 ReplicaSet을 1개씩 교체(무중단)하고, old RS가 0으로 남아 undo로 되돌린다.**

## 실습 확인 기록

### ① External traffic — Gateway 통해 hostname/path 라우팅
```text
$ kubectl -n envoy-gateway-system port-forward svc/envoy-week4-paperclip-gateway-184e87dc 8888:80
Forwarding from 127.0.0.1:8888 -> 10080

$ curl -s -i -H "Host: paperclip.local" http://localhost:8888/api
HTTP/1.1 200 OK
x-app-name: http-echo
x-app-version: 1.0.0
date: Thu, 02 Jul 2026 01:07:47 GMT
content-length: 47
content-type: text/plain; charset=utf-8

{"service":"api","version":"v1","status":"ok"}

$ curl -s -o /dev/null -w "http=%{http_code}\n" -H "Host: paperclip.local" http://localhost:8888/
http=200

$ curl -s -o /dev/null -w "http=%{http_code}\n" http://localhost:8888/api
http=404
```
- 읽는 포인트:
  - ⭐ `/api`→api(v1), `/`→frontend 로 **path 기반 분기**. 둘 다 200.
  - ⭐ Host 헤더 없으면 **404** = listener `hostname: paperclip.local` 매칭 실패. hostname이 라우팅의 1차 관문.

### ② Gateway가 왜 PROGRAMMED=False인지 확인 — 주소 미할당
```text
$ kubectl -n week4 get gateway
NAME                CLASS           ADDRESS   PROGRAMMED   AGE
paperclip-gateway   envoy-gateway             False        17h

$ kubectl -n week4 describe gateway paperclip-gateway
...
  Conditions:
    Message: The Gateway has been scheduled by Envoy Gateway
    Reason:  Accepted        Status: True   Type: Accepted
    Message: No addresses have been assigned to the Gateway
    Reason:  AddressNotAssigned   Status: False   Type: Programmed
  Listeners:
    Attached Routes:  1
    Conditions:
      Reason: Programmed    Status: True   Type: Programmed
      Reason: Accepted      Status: True   Type: Accepted
      Reason: ResolvedRefs  Status: True   Type: ResolvedRefs

$ kubectl -n envoy-gateway-system get svc
NAME                                     TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
envoy-week4-paperclip-gateway-184e87dc   LoadBalancer   10.96.91.208   <pending>     80:31772/TCP
```
- 읽는 포인트:
  - ⭐ 최상위 `Programmed=False (AddressNotAssigned)`인데 **Listener는 `Programmed/Accepted/ResolvedRefs` 다 True**, `Attached Routes: 1` → 라우팅은 정상, **주소만 없음**.
  - ⭐ 원인 = envoy proxy Service가 `LoadBalancer`인데 kind엔 LB 없어 `EXTERNAL-IP <pending>`. 그래서 ①은 NodePort(31772) 대신 port-forward로 접근함.

### ③ Rollout v1 → v2 (RollingUpdate, 무중단)
```text
$ kubectl -n week4 get deploy api -o jsonpath='{.spec.template.spec.containers[0].args[1]}'
-text={"service":"api","version":"v1","status":"ok"}

$ kubectl apply -f week4/day2/labs/traffic-routing/api-deployment-v2.yaml
deployment.apps/api configured

$ kubectl -n week4 rollout status deployment/api --timeout=60s
Waiting for deployment "api" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "api" rollout to finish: 1 old replicas are pending termination...
deployment "api" successfully rolled out

$ kubectl -n week4 get deploy api -o jsonpath='strategy={.spec.strategy.type} maxSurge={.spec.strategy.rollingUpdate.maxSurge} maxUnavailable={.spec.strategy.rollingUpdate.maxUnavailable}'
strategy=RollingUpdate maxSurge=25% maxUnavailable=25%

$ kubectl -n week4 get rs -l app=api
NAME             DESIRED   CURRENT   READY   AGE
api-7d5f896774   0         0         0       19h    # old(v1) → 0
api-7d6c56bb9    2         2         2       18s    # new(v2) → 2
```
- 읽는 포인트:
  - ⭐ `1 out of 2 new` → `1 old ... pending termination`: replicas 2 + 25% = **1개씩 교체**. new가 Ready된 뒤 old 내림 = 무중단.
  - ⭐ ReplicaSet 단위 교체: old RS(`api-7d5f896774`) 0, new RS(`api-7d6c56bb9`) 2.

### ④ Rollout 검증 + history + undo(rollback)
```text
# external로 v2 확인 (Gateway 통해)
$ curl -s -H "Host: paperclip.local" http://localhost:8888/api
{"service":"api","version":"v2","status":"ok"}

$ kubectl -n week4 rollout history deployment/api
REVISION  CHANGE-CAUSE
1         <none>
2         <none>

$ kubectl -n week4 rollout undo deployment/api
deployment.apps/api rolled back

$ kubectl -n week4 rollout status deployment/api --timeout=60s
deployment "api" successfully rolled out

$ curl -s -H "Host: paperclip.local" http://localhost:8888/api
{"service":"api","version":"v1","status":"ok"}
```
- 읽는 포인트:
  - ⭐ rollout 후 external 응답이 **v2로 바뀜** → 라우팅은 그대로, backend Pod만 교체됐어도 Service/Gateway 경로가 자동으로 새 Pod로 감.
  - ⭐ `undo`는 old RS(revision 1, 아직 존재)를 다시 scale up → **v1 복귀**. revision이 남아 있어야 rollback 됨.
  - ⚠️ `CHANGE-CAUSE <none>` = apply 시 변경 이유 미기록. 번호로만 되돌릴 수 있고 "뭘 바꿨나"는 안 남음.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| external traffic 경로? | 외부→Gateway(envoy svc)→HTTPRoute(hostname/path)→backend Service→Pod |
| Gateway가 PROGRAMMED=False면 고장? | 아님. kind는 LB 없어 EXTERNAL-IP pending(AddressNotAssigned). Listener는 Programmed, 라우팅 정상 |
| 외부 IP 없이 어떻게 접근? | NodePort(31772) 또는 port-forward. 실클라우드면 LB가 IP 할당 |
| Host 헤더가 왜 필요? | listener/HTTPRoute hostname(paperclip.local) 매칭. 없으면 404 |
| /api와 /가 다른 곳 가는 이유? | HTTPRoute path 규칙: /api→api, /→frontend (PathPrefix) |
| RollingUpdate가 1개씩 바꾼 이유? | maxSurge/maxUnavailable 25%, replicas 2 → 25%≈1개 |
| 무중단이 되는 원리? | new Pod가 readinessProbe 통과해 Ready된 뒤에야 old Pod 종료 |
| rollback(undo)이 되는 이유? | old ReplicaSet이 scale 0으로 남아 있어 다시 scale up |
| rollout 중 external 응답은? | 라우팅 그대로, backend Pod만 교체 → 자연스럽게 v1→v2로 바뀜 |
| CHANGE-CAUSE가 왜 none? | apply 시 --record/annotation 없어 변경 이유 미기록(번호만 남음) |

## notes

### Evidence Note
```markdown
# W4D2S7 Rollout & External Traffic
- external 경로: 외부 → envoy LoadBalancer svc(:80, port-forward 8888) → HTTPRoute(paperclip.local) → api/frontend svc → Pod
- Gateway Programmed=False 원인: envoy proxy svc=LoadBalancer, kind LB 없음 → EXTERNAL-IP <pending> → AddressNotAssigned. Listener는 Programmed/Attached Routes:1 (라우팅 정상)
- hostname 라우팅: Host paperclip.local + /api→api200, +/→frontend200, Host없음→404
- rollout: strategy RollingUpdate, maxSurge/maxUnavailable 25%, replicas 2 → 1개씩 교체
- RS 전환: old api-7d5f896774 0 / new api-7d6c56bb9 2
- 검증: external /api가 v1→v2로 바뀜. undo 후 다시 v1
- history CHANGE-CAUSE=<none> (변경 이유 미기록)
```

### Gateway 진단: 최상위 vs Listener condition 분리해서 봐라
```text
Gateway.status.Programmed=False  ← 최상위(주소 할당) 실패일 수 있음
Gateway.status.Listeners[].Programmed=True + Attached Routes>0  ← 라우팅은 정상
```
- ⭐ `PROGRAMMED=False` 한 줄만 보고 "라우팅 고장"이라 결론내지 말 것. Listener condition과 Attached Routes를 같이 봐야 "주소만 없음"을 구분.

### 무중단 배포의 3박자
```text
1) new Pod 생성 (maxSurge 만큼 초과 허용)
2) new Pod readinessProbe 통과 → Ready → Service endpoint 편입
3) old Pod 종료 (maxUnavailable 범위 내)
반복 → 트래픽 끊김 없이 v1 → v2
```
- ⚠️ readinessProbe가 없거나 잘못되면 준비 안 된 Pod로 트래픽이 가서 "무중단"이 깨짐.

### External Traffic vs 6교시 in-cluster
```text
6교시: Pod --curl http://api--> Service (클러스터 내부, NetworkPolicy 층)
7교시: 외부 --Host: paperclip.local--> Gateway/HTTPRoute --> Service (진입/라우팅 층)
```
- 층이 다름: NetworkPolicy(누가 갈 수 있나) / Gateway(외부에서 어디로 들어와 어디로 가나). external 문제는 Gateway·LB·hostname부터 본다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| Gateway `PROGRAMMED=False`, ADDRESS 비어 있음 | envoy proxy svc가 LoadBalancer인데 kind에 LB 없음 → EXTERNAL-IP `<pending>` → `AddressNotAssigned`. Listener는 Programmed(라우팅 정상) → 고장 아님 |
| 외부 IP가 없어 접근 불가로 보임 | NodePort `80:31772` 또는 port-forward(8888:80)로 접근 성공 |
| Host 없이 curl 하면 404 | listener/HTTPRoute hostname `paperclip.local` 매칭 실패. `-H "Host: paperclip.local"` 필요 |
| rollout history CHANGE-CAUSE가 `<none>` | apply에 `--record`/annotation 없어 변경 이유 미기록. revision 번호로만 undo 가능 |
