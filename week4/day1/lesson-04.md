# 4교시: ConfigMap과 Secret

## 핵심 정리

### 왜 image 밖 runtime config인가 — Docker `.env` 감각의 확장
```text
Docker Compose:  .env.dev / .env.staging / .env.prod  (환경별 파일 분리)
Kubernetes:      같은 image + ConfigMap/Secret object로 환경별 값 주입
                 → 이후 Terraform / External Secrets / cloud secret manager로 확장
```
- ⭐ 운영 기준 = **"동일 image를 환경별 runtime config로 다르게 실행한다."**
- image build 시점에 `ENV APP_ENV=prod` / `ENV API_TOKEN=...`을 박으면:

| 문제 | 설명 |
|---|---|
| image 재사용 불가 | dev/staging/prod마다 image가 달라짐 |
| secret 노출 | image layer/history에 민감정보가 남음 |
| 변경 속도 저하 | 설정 하나 바꿔도 build/push/rollout 필요 |
| 감사 어려움 | 어떤 환경값으로 실행됐는지 추적 애매 |

### ① ConfigMap — 민감하지 않은 운영 설정
```bash
export NS=week4
export LAB=week4/day1/labs/workload-basics
kubectl apply -f "$LAB/namespace.yaml"
kubectl apply -f "$LAB/configmap.yaml"
kubectl -n "$NS" get configmap api-config -o yaml
```
- ConfigMap은 **app code가 아니라 운영 설정.** 어떤 값이 적합한지 구분:

| 값 | ConfigMap 적합? | 이유 |
|---|---|---|
| `LOG_LEVEL=debug` | 적합 | 민감하지 않은 동작 설정 |
| `FEATURE_GREETING=enabled` | 적합 | feature flag 성격 |
| `API_BASE_URL=http://backend` | 대체로 적합 | 내부 endpoint |
| `DB_PASSWORD=...` | 부적합 | Secret 대상 |
| `JWT_PRIVATE_KEY=...` | 부적합 | Secret 또는 외부 secret manager |

### ② Secret — base64는 암호화가 아니다
```bash
kubectl apply -f "$LAB/secret.yaml"
kubectl -n "$NS" describe secret api-secret
```
- ⚠️ **`describe secret`은 값이 아니라 key와 byte 수만** 보여줌 → 안전하다고 착각 금지.
- `stringData` vs `data`:

| 필드 | 작성 방식 | 예시 |
|---|---|---|
| `stringData` | 사람이 읽는 plain string | `DEMO_API_TOKEN: local-demo-token` |
| `data` | base64 인코딩 값 | `DEMO_API_TOKEN: bG9jYWw...` |

- ⭐ 둘 다 **"암호화되어 안전"이 아니다.** base64는 누구나 되돌림:
```bash
echo 'bG9jYWw=' | base64 -d   # base64는 암호가 아니라 표현 방식
```
- 실제 secret 값은 **Git repo에 넣지 않는다.**

### ③ Pod 주입 — envFrom + args 치환
```yaml
envFrom:
  - configMapRef:
      name: api-config
  - secretRef:
      name: api-secret
```
- lab은 `hashicorp/http-echo` args에 `-text=$(RESPONSE_MESSAGE)` → **ConfigMap 값이 앱 응답**으로 나옴.
- ⚠️ Pod describe로 참조는 확인하되 **secret value를 `env`로 찍는 습관은 만들지 않는다.**

### ④ 설정 변경 ≠ Pod 자동 반영
```bash
kubectl -n "$NS" edit configmap api-config
kubectl -n "$NS" rollout restart deploy/runtime-api   # env는 container 시작 시점 주입
kubectl -n "$NS" rollout status deploy/runtime-api
```
- ⭐ **ConfigMap 수정(설정 object 변경)** 과 **rollout restart(새 설정으로 Pod 재시작)** 는 별개.
- envFrom으로 주입된 env는 **container 시작 시점에 고정** → 기존 Pod는 자동으로 안 바뀜.

### 실패 상황별 판단
| 증상 | 먼저 볼 곳 |
|---|---|
| Pod `CreateContainerConfigError` | ConfigMap/Secret 이름과 key |
| Pod는 뜨는데 값이 이상함 | ConfigMap data와 rollout 여부 |
| secret 값 바꿨는데 반영 안 됨 | 기존 Pod 재시작 여부 |

### Secret 주의사항 / 주입 방식 트레이드오프
| 오해 | 실제 |
|---|---|
| Secret이면 안전하다 | 기본은 base64 인코딩, 암호화 아님 |
| Git에 넣어도 된다 | 실제 secret 값은 Git에 안 넣음 |
| Pod env면 항상 안전 | describe 권한·process env 노출 고려 |
| 한 번 넣으면 끝 | rotation·만료·접근 권한 필요 |

| 방식 | 장점 | 주의 |
|---|---|---|
| env/envFrom | app 수정 적고 간단 | process env, crash dump, debug 출력 |
| volume mount | file 기반 key/cert에 적합 | app이 파일 reload 지원해야 함 |
| external secret | cloud secret manager 연결 | add-on·권한 설계 필요 |

- ⭐ 현업에서는 운영 secret을 Git의 Secret YAML에 직접 안 넣음 → **External Secrets Operator** 등장.

### External Secrets Operator preview
```text
AWS Secrets Manager / SSM Parameter Store
  -> External Secrets Operator
  -> Kubernetes Secret
  -> Pod env 또는 volume mount
```
- ⚠️ "ESO 쓰면 secret 고민 끝"이 아니다 → operator가 외부 secret 읽을 권한 + Secret 만들 권한 + Pod가 읽을 권한을 **모두 설계**해야 함.
- 실제 설치는 **W4D4에서 RBAC/ServiceAccount** 흐름과, provider 선택 기준은 **W5 AWS(Secrets Manager vs Parameter Store)** 에서 다시 연결.

### 한 줄 요약
> **ConfigMap과 Secret은 image를 환경에 종속시키지 않기 위한 runtime config 경계이며, Secret의 base64는 암호화가 아니다.**

## 실습 확인 기록

### ① ConfigMap 적용 — 넣은 값이 그대로 저장됐나
```text
$ kubectl apply -f $LAB/namespace.yaml
namespace/week4 unchanged
$ kubectl apply -f $LAB/configmap.yaml
configmap/api-config unchanged

$ kubectl -n week4 get configmap api-config -o yaml
apiVersion: v1
data:
  APP_ENV: dev
  FEATURE_GREETING: enabled
  LOG_LEVEL: debug
  RESPONSE_MESSAGE: hello from kubernetes runtime config
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{...},"kind":"ConfigMap","metadata":{...}}
  creationTimestamp: "2026-06-30T06:20:05Z"
  name: api-config
  namespace: week4
  resourceVersion: "37490"
  uid: 32aeb4c9-d55f-4628-ab26-9073407309ae
```
- 읽는 포인트:
  - `data`의 값이 **plain text 그대로** 보임 = ConfigMap은 숨김/암호화 대상이 아님 (민감정보 금지).
  - `RESPONSE_MESSAGE` = 뒤에서 Pod args `$(RESPONSE_MESSAGE)`로 치환되어 **앱 응답으로** 나올 값.
  - `apply` 출력이 **`unchanged`** = 이미 같은 내용으로 적용돼 있어 변경 없음 (idempotent). 값을 바꿔 재적용하면 `configured`로 바뀜.
  - `last-applied-configuration` annotation = `kubectl apply`가 **직전 적용본을 기억**해 3-way merge diff를 계산하는 근거.

### ② Secret describe — 값이 아니라 byte 수만
```text
$ kubectl apply -f $LAB/secret.yaml
secret/api-secret configured

$ kubectl -n week4 describe secret api-secret
Name:         api-secret
Namespace:    week4
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
DEMO_API_TOKEN:  26 bytes
```
- 읽는 포인트:
  - `apply` 출력이 **`configured`** = ①의 `unchanged`와 대비 → 내용이 새로 적용/변경됨. (같은 내용 재적용이면 unchanged가 뜸)
  - ⭐ **값 대신 `26 bytes`만** 보임 → "가려졌으니 안전"이 아니라 단지 출력을 안 할 뿐. (`local-demo-token-change-me` = 26글자)
  - `Type: Opaque` = 사용자 정의 임의 key/value Secret (기본 타입). TLS·docker-registry용 특수 타입과 구분됨.
  - `stringData`로 썼지만 저장 시 base64 `data`로 변환됨. base64는 되돌릴 수 있음(개념 시연용, 실제 token 값 아님):
```text
$ echo 'bG9jYWw=' | base64 -d
local
```
  - → base64는 **암호가 아니라 표현 방식**이라는 증거.

### ③ Pod 주입 확인 — describe의 envFrom + 앱 응답
```text
$ POD=$(kubectl -n week4 get pod -l app=runtime-api -o jsonpath='{.items[0].metadata.name}')
$ kubectl -n week4 describe pod "$POD"
Name:    runtime-api-557649f64d-8nzbj
...
Containers:
  api:
    Image:  hashicorp/http-echo:1.0
    Args:
      -listen=:8080
      -text=$(RESPONSE_MESSAGE)         ← describe엔 치환 전 원본이 보임
    State:          Running
    Last State:     Terminated
      Reason:       Unknown
      Exit Code:    255
    Ready:          True
    Restart Count:  1                    ← 밤새 노트북 sleep으로 1회 재시작
    Environment Variables from:
      api-config  ConfigMap  Optional: false
      api-secret  Secret     Optional: false
    Environment:  <none>
QoS Class:  Burstable
Events:     <none>
```
- 읽는 포인트:
  - **`Environment Variables from:`** 에 ConfigMap·Secret이 잡힘 = Pod가 두 object를 참조한 증거.
  - ⭐ **secret value 자체는 출력 안 됨** (`Environment: <none>`도 개별 env가 없다는 뜻) → 확인하려고 `env` 찍는 습관 만들지 않음.
  - ⭐ **`Args`에 `$(RESPONSE_MESSAGE)`가 치환 안 된 채로** 보임 → describe는 spec 원본을 보여줄 뿐, 실제 값 치환은 **container 시작 시 안에서** 일어남. 그래서 값 확인은 ④의 **앱 응답(curl)** 으로 함.
  - `Restart Count: 1` + `Last State: Terminated / Exit Code: 255` = 컨테이너가 한 번 죽고 다시 뜸 (노트북 sleep 등으로 kubelet이 재시작). **`Ready: True`라 현재는 정상** — restart 이력이 곧 장애는 아님.
  - `QoS Class: Burstable` = requests(25m/32Mi) < limits(100m/64Mi)라 부여됨. requests=limits면 Guaranteed.
```text
$ kubectl -n week4 run curlbox --rm -it --restart=Never \
    --image=curlimages/curl:8.10.1 -- curl -s http://runtime-api
warning: couldn't attach to pod/curlbox, falling back to streaming logs: ...
hello from kubernetes runtime config
pod "curlbox" deleted from week4 namespace
```
  - ⭐ 이 응답은 **image에 고정된 값이 아니라 ConfigMap `RESPONSE_MESSAGE`** 에서 온 값 → runtime config가 실제로 앱까지 도달함을 증명. (③ describe에서 `$(RESPONSE_MESSAGE)`였던 게 여기서 실제 값으로 치환됨)
  - `warning: couldn't attach ... falling back to streaming logs` = 임시 Pod가 너무 빨리 뜨고 끝나 attach 타이밍을 놓친 것 → **로그로 대체**되어 결과는 정상 수신. 무시해도 됨.
  - `--rm`이라 curl이 끝나자 **Pod가 자동 삭제**(`curlbox deleted`) → 확인용 임시 Pod를 남기지 않음.
  - `http://runtime-api`로 접근 = Service 이름이 **cluster 내부 DNS**로 풀림 (같은 namespace라 짧은 이름으로 됨).

### ④ 설정 변경 후 rollout — 자동 반영 안 됨을 확인
```text
$ kubectl -n week4 get rs,pod -l app=runtime-api      # rollout 전
NAME                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/runtime-api-557649f64d   2         2         2       18h
NAME                               READY   STATUS    RESTARTS      AGE
pod/runtime-api-557649f64d-8nzbj   1/1     Running   1 (73m ago)   18h
pod/runtime-api-557649f64d-njlc7   1/1     Running   1 (73m ago)   18h

$ kubectl -n week4 rollout restart deploy/runtime-api
deployment.apps/runtime-api restarted

$ kubectl -n week4 rollout status deploy/runtime-api
Waiting for deployment "runtime-api" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "runtime-api" rollout to finish: 1 old replicas are pending termination...
deployment "runtime-api" successfully rolled out

$ kubectl -n week4 get rs,pod -l app=runtime-api      # rollout 후
NAME                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/runtime-api-557649f64d   0         0         0       18h   ← 이전 RS (0으로 내려감)
replicaset.apps/runtime-api-78975fb9df   2         2         2       20s   ← 새 RS
NAME                               READY   STATUS    RESTARTS   AGE
pod/runtime-api-78975fb9df-8sl6l   1/1     Running   0          20s
pod/runtime-api-78975fb9df-n22w2   1/1     Running   0          14s
```
- 읽는 포인트:
  - ⭐ **ConfigMap을 edit해도 기존 Pod env는 안 바뀜** → `rollout restart`로 새 Pod를 만들어야 새 값이 주입됨. env는 **container 시작 시점에 주입**되어 고정되기 때문. 설정 변경과 workload 재시작은 **별개 작업**.
  - **RS 해시가 바뀜** (`557649f64d` → `78975fb9df`) = Pod template이 바뀐 것으로 취급되어 **새 ReplicaSet** 생성. 이전 RS는 `2→0`으로 내려가고 새 RS가 `0→2`로 올라옴 (W3D5 rollout 흐름과 동일).
  - `rollout status` 로그가 **점진적 교체**를 보여줌: `1 out of 2 new... updated` → `1 old... pending termination` → 완료. 한 번에 다 죽이지 않고 **한 개씩** 갈아끼워 무중단 유지.
  - rollout 후 새 Pod는 `RESTARTS 0` (방금 떠서 깨끗함). 이전 Pod의 `RESTARTS 1`(sleep 재시작 이력)은 RS와 함께 사라짐.
  - 참고: `rollout restart`는 ConfigMap 값을 안 바꿔도 **Pod를 새로 뜨게** 함 → edit한 ConfigMap 값을 다시 읽게 만드는 표준 방법.

### ⑤ 설정 누락 실패 — describe events가 먼저
```text
$ kubectl -n week4 describe pod <pod-name>
...
Events:
  Warning  Failed  ...  Error: configmap "api-config-missing" not found
  Warning  Failed  ...  Error: secret "api-secret-missing" not found
```
- 읽는 포인트:
  - ConfigMap/Secret 이름이 틀리면 Pod는 `CreateContainerConfigError`로 **시작 못 함**.
  - ⭐ 이때는 **app log보다 `kubectl describe pod`의 Events를 먼저** 본다 (원인이 앱이 아니라 주입 단계).

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| image 안에 설정을 박으면 안 되는 이유? | image 재사용 불가·secret 노출·변경 속도 저하·감사 어려움. 동일 image를 환경별 runtime config로 실행해야 함 |
| ConfigMap과 Secret의 구분 기준? | 민감하지 않은 동작/feature 설정=ConfigMap, 민감정보(암호·key·token)=Secret |
| Secret은 암호화되어 안전한가? | 아님. 기본은 base64 인코딩이며 `base64 -d`로 되돌림. 실제 값은 Git에 안 넣음 |
| `stringData`와 `data`의 차이? | stringData=plain string 입력(저장 시 base64로 변환), data=base64 인코딩 값 직접 입력 |
| ConfigMap 수정하면 Pod가 자동으로 바뀌나? | 아님. env는 container 시작 시점 주입 → `rollout restart`로 새 Pod를 만들어야 반영 |
| ConfigMap/Secret 이름이 틀리면? | Pod가 `CreateContainerConfigError`. app log보다 `describe pod`의 Events를 먼저 봄 |
| External Secrets Operator가 secret 고민을 끝내주나? | 아님. 외부 secret 읽기·Secret 생성·Pod 읽기 권한을 모두 설계해야 함 (W4D4 RBAC) |

## notes

### Evidence Note
```markdown
# W4D1S4 ConfigMap/Secret
- ConfigMap에 넣은 값:
- Secret에 넣으면 안 되는 방식:
- Pod describe에서 envFrom 확인:
- 앱 응답으로 확인한 runtime config:
- 설정 변경 후 필요한 rollout 작업:
```

### base64 ≠ 암호화 — 이번 교시의 핵심 오해
- `describe secret`이 값을 안 보여줘도 저장은 base64일 뿐 → `echo <b64> | base64 -d`로 즉시 복원.
- 3교시 "deployed ≠ Ready", W3D5 "200 나와도 배포 성공 아님"과 같은 결: **표면 출력을 안전/성공으로 착각하지 않기.**

### Docker `.env` → Kubernetes 확장 매핑
```text
.env 파일        → ConfigMap/Secret, 환경별 manifest
CI secret        → GitHub Secret, cloud secret store
운영 secret store → External Secrets Operator
cloud IAM        → ServiceAccount + workload identity
```
- 오늘은 env/envFrom 입문 → W4D4에서 RBAC/ESO, W5 AWS에서 Secrets Manager vs Parameter Store로 연결.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
