# 6교시: Resource Requests/Limits

## 핵심 정리

### requests vs limits — 예약 vs 상한
| 설정 | 역할 | 운영 의미 |
|---|---|---|
| `requests.cpu` | 필요한 CPU **예약** | scheduler가 **node 배치 판단**에 사용 |
| `requests.memory` | 필요한 memory 예약 | node capacity 계획 기준 |
| `limits.cpu` | CPU 사용 **상한** | 초과 시 **throttling**(느려짐) |
| `limits.memory` | memory 사용 상한 | 초과 시 **OOMKilled**(죽음) |

- ⭐ 한 문장: **requests = 배치 약속(scheduler가 봄), limits = 사용 상한(초과 시 제재).**

### CPU/Memory 단위 — `m`은 milli다
| 표현 | 의미 |
|---|---|
| `100m` CPU | 0.1 core (⚠️ "메가"가 아니라 **milli**) |
| `500m` CPU | 0.5 core |
| `1` CPU | 1 core |
| `64Mi` memory | 64 mebibytes |
| `512Mi` memory | 512 mebibytes |

- ⚠️ `100m`을 "100 메가 CPU"로 오해하면 값을 전혀 다르게 잡음.

### ① 선언값 확인 — describe / custom-columns
```bash
export NS=week4
kubectl -n "$NS" describe pod -l app=runtime-api        # Limits/Requests 확인
kubectl -n "$NS" get pod -l app=runtime-api \
  -o custom-columns=NAME:.metadata.name,\
CPU_REQ:.spec.containers[0].resources.requests.cpu,\
MEM_REQ:.spec.containers[0].resources.requests.memory,\
CPU_LIM:.spec.containers[0].resources.limits.cpu,\
MEM_LIM:.spec.containers[0].resources.limits.memory
```
- ⭐ 이 출력은 **"지금 얼마나 쓰는가"가 아니라 "어떤 기준으로 선언됐는가"**. 실제 사용량은 7교시 `kubectl top`.
- `kubectl get pod` 기본 출력엔 resource가 안 보임 → describe나 custom-columns 필요.

### scheduler는 실제 사용량이 아니라 request를 본다
```text
node capacity: 2 CPU
Pod들의 request 합계가 node 여유를 넘으면 → 새 Pod는 Pending
(실제 CPU를 거의 안 써도, request 기준으로 자리가 없으면 배치 안 됨)
```

| 상태 | 해석 |
|---|---|
| 실제 사용량 낮음 | 이미 뜬 Pod의 현재 사용량 |
| request 합계 높음 | scheduler가 **예약**한 capacity |
| Pending | request 만족하는 node 없음 |

### ② OOMKilled 실험 — limit 초과는 kernel이 죽인다
```bash
kubectl apply -f week4/day1/labs/workload-basics/pod-oom-demo.yaml  # memory 계속 할당
kubectl -n week4 get pod oom-demo -w
kubectl -n week4 describe pod oom-demo
```
- ⭐ **`Reason: OOMKilled` / `Exit Code: 137`** = memory limit(48Mi) 넘어 **kernel이 강제 종료**. 앱 정상 종료 아님.
- `get pod`엔 `STATUS Error`만 보임 → 원인은 **describe나 jsonpath**로:
```bash
kubectl -n week4 get pod oom-demo \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
```
- 정리: `kubectl -n week4 delete pod oom-demo --ignore-not-found`

### ③ request가 너무 크면 Pending — log가 아니라 event
```bash
kubectl -n week4 describe pod <pending-pod>   # Events를 먼저
```
- 대표 메시지: `0/1 nodes are available: insufficient cpu` / `insufficient memory`

| 출력 | 의미 |
|---|---|
| `Pending` | scheduler가 배치 못 함 |
| `insufficient cpu/memory` | request 만족할 capacity 없음 |
| **log 없음** | container가 **시작 안 됨** → 정상 (scheduler 단계 문제) |

### CPU throttling은 왜 더 어렵나
```text
CPU limit 낮음 → 처리 시간 늘어남 → readiness timeout 가능 → 사용자는 latency 증가
```
- ⭐ **memory 초과 = OOMKilled(선명하게 죽음)**, **CPU 초과 = throttling(안 죽고 느려짐)** → CPU 문제는 눈에 덜 띔. W4D3 Prometheus/Grafana에서 깊게 봄.

### 비용 연결 & sizing 감각
- request ↑ → scheduler가 더 많은 node capacity 필요로 판단 → **node 수/instance size/autoscaling/비용** ↑.
- limit 너무 낮음 → 자주 죽거나 느려짐. limit 너무 높음 → **noisy neighbor**(한 Pod가 자원 독식).

| 서비스 성향 | CPU | Memory | 주의 |
|---|---|---|---|
| API gateway | 중간 | 낮음~중간 | connection·timeout |
| JSON CRUD API | 중간 | 중간 | DB latency, thread pool |
| image 처리 | 높음 | 높음 | CPU limit, memory peak |
| cache | 낮음~중간 | 높음 | memory limit·eviction |
| database | 중간 | 높음 | 보통 managed service |

- ⚠️ "모든 container에 같은 limit" = 착각. 성향별로 다름.

### storage scheduling preview (W5 회수)
- Pod 배치는 CPU/memory만이 아님. volume이 붙으면 **storage가 갈 수 있는 node/zone**도 scheduler에 영향.
- `volumeBindingMode: WaitForFirstConsumer` = Pod가 실제 스케줄될 때까지 volume binding을 미룸 → zone 불일치 방지.
- AWS EBS는 **zonal**: `us-east-1a`의 volume은 `1b` node에 attach 불가 → zone 안 맞으면 Pending/attach 실패. 공유 필요하면 EFS/RDS 검토. (W5 AWS Storage)

### 운영 기준
```text
초기값 선언 → metrics 관찰 → peak/idle 비교 → requests/limits 조정 → rollout
```
- ⭐ 완벽한 값은 처음부터 어려움. 하지만 **아예 선언 안 하는 게 더 위험** → 최소값 넣고 조정하는 루프.

### 한 줄 요약
> **requests는 배치 약속(scheduler 기준), limits는 사용 상한. memory 초과는 OOMKilled로 죽고, CPU 초과는 throttling으로 느려진다.**

## 실습 확인 기록

### ① 선언값 확인 — 사용량이 아니라 "선언 기준"
```text
$ kubectl -n week4 describe pod -l app=runtime-api
...
    Limits:
      cpu:     100m
      memory:  64Mi
    Requests:
      cpu:      25m
      memory:   32Mi
...
QoS Class:  Burstable

# zsh는 [0]을 glob으로 오해 → custom-columns 값 전체를 작은따옴표로 감쌈
$ kubectl -n week4 get pod -l app=runtime-api \
    -o 'custom-columns=NAME:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:...,CPU_LIM:...,MEM_LIM:...'
NAME                           CPU_REQ   MEM_REQ   CPU_LIM   MEM_LIM
runtime-api-78975fb9df-8sl6l   25m       32Mi      100m      64Mi
runtime-api-78975fb9df-n22w2   25m       32Mi      100m      64Mi
```
- 읽는 포인트:
  - **requests(25m/32Mi) < limits(100m/64Mi)** → describe의 **`QoS Class: Burstable`** 근거 (5교시에서 본 값). requests=limits면 Guaranteed.
  - 이 값은 **선언(spec)** 이지 현재 사용량이 아님. "얼마 쓰는지"는 `kubectl top`(7교시).
  - `get pod` 기본 출력엔 안 나와서 **custom-columns로 뽑음** = jsonpath로 원하는 필드만 표로. `[0]` = 첫 번째 container.
  - ⚠️ zsh에선 `[0]`을 파일 glob으로 오해해 `no matches found` → **작은따옴표로 감싸야** 함 (`"$NS"`의 공백 방지와 같은 shell quoting 이슈, 이번엔 `[]` 특수문자).

### ② OOMKilled — memory limit 넘으면 kernel이 죽임
```text
$ kubectl -n week4 get pod oom-demo -w
NAME       READY   STATUS              RESTARTS   AGE
oom-demo   0/1     ContainerCreating   0          3s
oom-demo   1/1     Running             0          5s
oom-demo   0/1     OOMKilled           0          5s     ← 뜨자마자 5초 만에 죽음
# (watch는 스스로 안 끝남 → Ctrl+C로 빠져나옴)

$ kubectl -n week4 describe pod oom-demo
Status:  Failed
...
    State:          Terminated
      Reason:       OOMKilled
      Exit Code:    137
      Started:      ...11:40:31
      Finished:     ...11:40:31        ← Started=Finished (거의 즉사)
    Restart Count:  0
    Limits:
      memory:  48Mi

$ kubectl -n week4 get pod oom-demo \
    -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}{"\n"}'
OOMKilled
```
- 읽는 포인트:
  - ⭐ **`OOMKilled`**(= **O**ut **O**f **M**emory + Killed) **+ `Exit Code: 137`** = memory limit(48Mi) 초과 → **kernel의 OOM Killer가 강제 종료**. `137 = 128 + 9`(SIGKILL 신호 번호).
  - **`Status: Failed`** (Pod 레벨) + **`State: Terminated`** (container 레벨). 요즘 kubectl은 `get pod` STATUS에 `OOMKilled`를 **바로** 보여줌 (예전엔 `Error`).
  - ⚠️ jsonpath는 **`state.terminated`** (현재 종료 상태). `lastState`는 **재시작 후** 직전 상태를 볼 때 씀 → `restartPolicy: Never`라 재시작이 없어 여기선 `state`가 맞음. (lastState로 조회하면 빈 값)
  - `restartPolicy: Never`라 재시작 없이 `Failed`로 남음 (Deployment였다면 CrashLoop처럼 restart 반복).
  - `Started == Finished` = python이 `"x"*1MB`를 무한 append → 뜨자마자 48Mi 넘겨 즉사.
  - 정리: `kubectl -n week4 delete pod oom-demo --ignore-not-found`

### ③ Pending — request가 capacity보다 크면 (event가 핵심) *[미실습·개념]*
> lab 파일 없음(강의자료도 개념만). 아래는 예상 출력. 재현하려면 `memory: 100Gi` 요청 Pod를 heredoc으로 만들면 됨.
```text
$ kubectl -n week4 get pod too-large-pod
NAME            READY   STATUS    RESTARTS   AGE
too-large-pod   0/1     Pending   0          20s

$ kubectl -n week4 describe pod too-large-pod
...
Events:
  Warning  FailedScheduling  ...  0/1 nodes are available: 1 Insufficient cpu. ...
```
- 읽는 포인트:
  - ⭐ **`Pending` + `Insufficient cpu`** = request를 만족할 node가 없어 scheduler가 배치 못 함. (실제 사용량이 아니라 **request 기준**)
  - **app log가 없음** = container가 아예 시작 안 됨 → 정상. Pending은 **scheduler 단계** 문제라 `describe`의 Events가 핵심.
  - kind는 node가 control-plane 하나뿐이라, request를 node capacity보다 크게 잡으면 쉽게 재현됨.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| requests와 limits의 차이? | requests=scheduler가 배치에 쓰는 예약값, limits=사용 상한(초과 시 제재) |
| scheduler가 보는 건 사용량? request? | **request.** 실제 사용량이 낮아도 request 합계가 node를 넘으면 Pending |
| `100m` CPU는? | 0.1 core. `m`=milli (메가 아님) |
| OOMKilled는 왜 발생? | container가 memory limit 초과 → kernel이 강제 종료(Exit 137). 앱 정상 종료 아님 |
| `STATUS Error`만 보고 원인 알 수 있나? | 아님. describe/jsonpath의 lastState.terminated.reason으로 OOMKilled 확인 |
| Pending이면 먼저 볼 곳? | app log 아님(시작 안 됨). `describe pod`의 Events(insufficient cpu/memory) |
| memory 초과 vs CPU 초과 차이? | memory=OOMKilled로 죽음(선명), CPU=throttling으로 느려짐(안 죽어 덜 띔) |

## notes

### Evidence Note
```markdown
# W4D1S6 Resources
- runtime-api requests:
- runtime-api limits:
- OOMKilled 확인 결과:
- Pending이면 먼저 볼 명령:
- CPU limit이 낮을 때 나타날 수 있는 사용자 영향:
```

### 선언값 ≠ 사용량 — 이번 교시 핵심 구분
```text
requests/limits (spec)  = 내가 선언한 예약·상한   → describe / custom-columns
실제 사용량              = 지금 진짜 쓰는 양        → kubectl top (7교시)
```
- 5교시 "선언을 믿지 말고 실물로 확인"과 같은 결. 선언과 실사용을 섞지 않기.

### 실패 양상별 판단
| 증상 | 원인 | 먼저 볼 것 |
|---|---|---|
| `OOMKilled` / Exit 137 | memory limit 초과 | describe·jsonpath (lastState) |
| `Pending` / insufficient | request > capacity | describe Events (scheduler) |
| latency 증가 (안 죽음) | CPU throttling | kubectl top → Prometheus (W4D3) |

### QoS Class 연결 (5교시 describe에서 본 값)
```text
requests = limits           → Guaranteed  (가장 늦게 evict)
requests < limits           → Burstable   (runtime-api가 여기)
requests/limits 둘 다 없음   → BestEffort  (가장 먼저 evict)
```
- node memory 압박 시 evict 우선순위가 이 QoS로 갈림.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
