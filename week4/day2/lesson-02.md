# 2교시: MSA 앱 내부 통신

## 핵심 정리

### 오늘의 앱 구조 — 3-tier MSA
```text
외부 사용자 → (Gateway/HTTPRoute, 3·4교시) → frontend → api → postgres
```
- ⭐ **외부 사용자는 db에 직접 접근 안 함.** 진입점은 Gateway/HTTPRoute, db는 **cluster 내부 backend**만 접근.
- 1교시에서 올린 frontend ×2 / api ×2 / postgres ×1이 그대로 대상.

### Service port vs targetPort (1교시 named port 심화)
```yaml
# api Service
ports:
  - name: http
    port: 80          # client가 호출하는 port
    targetPort: http  # Pod containerPort "이름" → 실제 8080
```

| 항목 | 의미 |
|---|---|
| `port: 80` | client가 `http://api`로 호출하는 port |
| `targetPort: http` | Pod containerPort **이름** (숫자 아님) |
| Endpoint `:8080` | 실제 Pod가 듣는 port |

- ⭐ `targetPort`가 이름(`http`)이라 **containerPort 번호가 바뀌어도 이름만 맞으면** Service 수정 불필요.

### 내부 DNS 호출 — Service 이름으로
```bash
kubectl -n week4 run curlbox --rm -it --restart=Never \
  --image=curlimages/curl:8.10.1 -- curl -s http://api/api
# 기대: {"service":"api","version":"v1","status":"ok"}
```
- ⭐ 오류로 **DNS 실패 vs connection 실패**를 구분:

| 오류 | 의미 | 먼저 볼 것 |
|---|---|---|
| `curl: (6) Could not resolve host: api` | **DNS 실패** | Service 이름/namespace, CoreDNS |
| `curl: (7) Failed to connect to api port 80` | DNS는 됐고 **connection 실패** | endpoint/port, readiness |

### db 접근 기준 — ClusterIP로 내부에만
```bash
kubectl -n week4 get svc postgres      # ClusterIP, 5432/TCP
```
- ⭐ postgres는 **ClusterIP** = cluster 내부에서만 `postgres:5432`로 접근. 외부 노출 안 함.
- 오늘 api container엔 실제 DB client가 없어 접속까지는 안 감 → **service 구조·경계**만 확인.

### frontend가 db를 직접 알면 안 되는 이유
| 문제 | 설명 |
|---|---|
| 보안 | browser/client 계층이 DB 정보를 알게 됨 |
| 네트워크 경계 | db를 내부 backend로 숨기기 어려움 |
| 변경 영향 | DB 교체/분리 시 frontend까지 영향 |
| 권한 | frontend에 과도한 DB 접근 권한 필요 |

- ⭐ **"Service가 있다 = 모두에게 열어야 한다"가 아니다.** 계층별로 접근을 제한 (→ 6교시 NetworkPolicy로 강제).

### 내부 통신 장애 판단
| 증상 | 먼저 볼 명령 | 이유 |
|---|---|---|
| `Could not resolve host` | `get svc api` | Service 이름/namespace |
| connection refused | `get endpoints api` | endpoint/port |
| timeout | NetworkPolicy, Pod readiness | 차단 또는 준비 실패 |
| API 응답 이상 | `logs deploy/api` | app process |

### 한 줄 요약
> **내부 통신은 Service DNS로 하고, port(client)와 targetPort(Pod)를 구분해야 장애를 빨리 찾는다. db는 ClusterIP 내부 backend로 숨긴다.**

## 실습 확인 기록

### ① 전체 구조 확인 — deploy/pod/svc/endpoints
```text
$ kubectl -n week4 get deploy,svc -o wide
NAME                       READY
deployment.apps/frontend   2/2
deployment.apps/api        2/2
deployment.apps/postgres   1/1

service/frontend   ClusterIP   80/TCP
service/api        ClusterIP   80/TCP
service/postgres   ClusterIP   5432/TCP
```
- 읽는 포인트:
  - frontend/api는 `80/TCP`(HTTP), **postgres는 `5432/TCP`**(DB 포트) → 계층별로 다른 port.
  - api/frontend replica 2 → endpoint 2개, postgres 1 → endpoint 1개.

### ② 내부 DNS 호출 — frontend → api
```text
$ kubectl -n week4 run curlbox --rm -it --restart=Never \
    --image=curlimages/curl:8.10.1 -- curl -s -i http://api/api
HTTP/1.1 200 OK
X-App-Name: http-echo
X-App-Version: 1.0.0
Content-Length: 47
Content-Type: text/plain; charset=utf-8

{"service":"api","version":"v1","status":"ok"}
```
- 읽는 포인트:
  - ⭐ **`http://api`(Service DNS) → `200 OK` + JSON** = 내부 통신 정상. Pod IP가 아니라 Service 이름으로 호출.
  - 응답 body `"version":"v1"` = **앱 논리 버전** (7교시 rollout에서 v2로 바뀜, 여기와 비교). vs 헤더 `X-App-Version: 1.0.0` = **http-echo 이미지 버전** (둘은 다른 것).
  - ⚠️ 경로 오타(`/ap`) + `-s`(silent)면 에러도 없이 빈 화면 → `-i`로 상태코드(`200 OK`)까지 봐야 확실. `curl (6)`=DNS, `(7)`=connection.

### ③ db 경계 확인 — postgres ClusterIP/endpoint
```text
$ kubectl -n week4 get svc postgres
NAME       TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
postgres   ClusterIP   10.96.66.98   <none>        5432/TCP   30m
```
- 읽는 포인트:
  - ⭐ **`TYPE ClusterIP` + `EXTERNAL-IP <none>`** = 외부에서 접근 불가, cluster 내부에서만 `postgres:5432`로 접근하는 backend. 외부 진입점(Gateway)엔 안 붙임.
  - **`5432/TCP`** = PostgreSQL 기본 포트 (frontend/api의 80과 다른 계층 포트).
  - endpoint(`kubectl -n week4 get endpoints postgres`)에 Pod IP `10.244.0.9:5432` 1개 = api가 접근할 기반 준비됨. (실제 DB 접속은 오늘 범위 밖 — 구조·경계만)

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| MSA 앱 traffic 구조? | 외부 → Gateway/HTTPRoute → frontend → api → postgres. db는 직접 노출 안 함 |
| Service port와 targetPort 차이? | port=client가 호출하는 port, targetPort=Pod containerPort(이름/번호). Service가 매핑 |
| `targetPort: http`가 이름인 이유? | container named port 참조 → containerPort 번호 바뀌어도 이름만 맞으면 됨 |
| `curl (6)`과 `curl (7)` 차이? | (6)=DNS 실패(이름 못 찾음), (7)=DNS는 됐고 connection 실패(endpoint/port) |
| postgres를 ClusterIP로 두는 이유? | cluster 내부 backend로만 접근. 외부/frontend에 직접 노출 안 함 |
| frontend가 db를 직접 알면 안 되는 이유? | 보안·경계·변경영향·권한. Service 있다고 다 열지 않음 |
| 내부 통신 timeout이면? | NetworkPolicy 차단 또는 Pod readiness 실패 의심 |

## notes

### Evidence Note
```markdown
# W4D2S2 Internal service DNS
- frontend Service: ClusterIP 80/TCP
- api Service: ClusterIP 80/TCP (targetPort http → 8080)
- postgres Service: ClusterIP 10.96.66.98, EXTERNAL-IP <none>, 5432/TCP (내부 backend)
- api Endpoint: 10.244.0.7:8080, 10.244.0.8:8080
- 내부 curl 결과: curl -i http://api/api → 200 OK, {"service":"api","version":"v1","status":"ok"}
- DNS 실패와 connection 실패 차이: curl(6)=DNS 실패(이름), curl(7)=connection 실패(endpoint/port)
```

### port 3층 정리 (1교시 named port 완성)
```text
client:  http://api        → :80        (Service port)
Service: targetPort: http  → 이름 참조
Pod:     containerPort http = :8080     (Endpoint에 :8080으로 나타남)
```
- 사용자는 80만 알면 되고, 내부 8080은 Service가 감춤. 번호가 바뀌어도 이름으로 흡수.

### 계층별 노출 정책 (6교시 NetworkPolicy 예고)
```text
frontend  → 외부 노출 대상 (Gateway가 붙음)
api       → frontend에서만 호출 (내부)
postgres  → api에서만 호출 (내부 backend, 가장 안쪽)
```
- 오늘은 "구조상 그렇게 둔다"까지. 6교시에서 NetworkPolicy로 **실제 차단**을 건다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
