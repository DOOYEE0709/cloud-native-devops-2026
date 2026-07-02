# 5교시: 장애와 Metric 연결

## 핵심 정리

### metric은 "언제·얼마나", logs/events는 "왜"
```text
metric  → 장애의 시간·범위 (restart 늘었다, ready 줄었다, CPU 올랐다)
logs/events → 원인 (왜 죽었나, 왜 not ready인가)
```
- ⚠️ metric만 보고 결론 X. 반드시 logs/events와 **한 화면**에 연결.

### 장애 3종과 metric 시그니처
| 시나리오 | 무엇 | metric 시그니처 | 원인 증거 |
|---|---|---|---|
| CrashLoop | `exit 1` 반복 | restart 증가, ready=0 | `logs --previous`, BackOff event |
| readiness 실패 | probe /not-ready(404) | **restart 안 늘고** ready=0 | Readiness probe failed event |
| CPU 압박 | `while true` loop | CPU rate가 limit까지 | top pod, limit 확인(throttling) |

- ⭐ **restart만 보면 readiness 장애를 놓친다** — readiness 실패는 restart가 안 늘 수 있음. ready metric을 따로 봐야 함.

### metric ↔ 원인 연결표
| metric 변화 | 원인 후보 | 함께 볼 것 |
|---|---|---|
| restart 증가 | CrashLoop, OOMKilled | logs --previous, describe |
| ready 감소 | readiness 실패, rollout 실패 | endpoints, events |
| CPU 증가 | loop, 부하, throttling | app latency, top pod |
| memory 증가 | leak, cache, batch | OOMKilled, working set |
| target down | scrape 실패 | target error, ServiceMonitor |

### ⚠️ increase()의 window를 잘못 잡으면 장애를 놓친다
- ⭐ CrashLoopBackOff는 **지수 backoff**로 재시작 간격이 벌어짐 → `increase(restarts[5m])`가 0이어도 실제로는 crashloop 중일 수 있음. window를 넓히거나 total count도 같이 봄.

### 한 줄 요약
> **metric은 장애의 시간과 범위를 보여주고 logs/events는 원인을 좁히는 증거다. restart/ready/CPU를 따로 보고(restart만 보면 readiness 장애를 놓침), increase() window에 따라 결과가 달라지므로 total과 함께 확인한다.**

## 실습 확인 기록

### ① 장애 3종 배포 + kubectl 증상
```text
$ kubectl apply -f week4/day3/labs/observability-scenarios/namespace.yaml
$ kubectl apply -f week4/day3/labs/observability-scenarios/crashloop-demo.yaml
$ kubectl apply -f week4/day3/labs/observability-scenarios/cpu-pressure-demo.yaml
$ kubectl apply -f week4/day3/labs/observability-scenarios/readiness-bad-demo.yaml

$ kubectl -n week4-observe get pod
NAME                                  READY   STATUS             RESTARTS      AGE
cpu-pressure-demo-54f47c664d-t44q9    1/1     Running            0             4m46s
crashloop-demo-6dfff677b9-qhpx5       0/1     CrashLoopBackOff   5 (73s ago)   4m46s
readiness-bad-demo-5bf7f7d96f-pj8q4   0/1     Running            0             4m46s
```
- 읽는 포인트:
  - ⭐ 세 장애가 STATUS로 구분됨: crashloop=`CrashLoopBackOff`(RESTARTS 증가), readiness-bad=`Running`인데 **0/1**(안 죽고 not ready), cpu-pressure=`1/1 Running`(겉보기 정상).
  - ⚠️ readiness-bad는 `Running`이라 `get pod` STATUS만 보면 정상처럼 보임 → **READY 컬럼(0/1)**을 봐야 함.

### ② CrashLoop — restart metric + 원인 증거
```text
# metric: kube_pod_container_status_restarts_total{namespace="week4-observe"}
crashloop     7
cpu-pressure  0
readiness-bad 0

# increase() window에 따라 다름 (지수 backoff 때문)
increase(...restarts...[5m])  = 0      ← 최근 5분엔 안 튐 (backoff로 간격 벌어짐)
increase(...restarts...[15m]) = 3.1
increase(...restarts...[30m]) = 8.15   ← 넓게 보면 명확히 증가

# 원인: kubectl logs deploy/crashloop-demo --previous
intentional restart for observability

# event: describe pod -l app=crashloop-demo
Warning  BackOff  ...(x17)  Back-off restarting failed container crash in pod crashloop-demo-...
```
- 읽는 포인트:
  - ⭐ total 7 = restart 발생 확실. 그런데 **`increase[5m]=0`** → backoff로 간격이 벌어져 최근 창엔 안 잡힘. **window 넓히면(15m=3.1, 30m=8.15) 보임**. window 하나만 믿으면 crashloop을 "정상"으로 오판.
  - ⭐ metric은 "재시작 늘었다"까지, **`logs --previous`가 "왜"**(=의도적 exit 1). event `Back-off restarting`은 kubelet의 재시작 억제.

### ③ readiness 실패 — restart 없이 ready=0
```text
# metric: kube_pod_status_ready{namespace="week4-observe", condition="true"}  (1=ready, 0=notready)
cpu-pressure   1
crashloop      0
readiness-bad  0

# restart는? readiness-bad restart total = 0 (안 늘어남)

# event: describe pod -l app=readiness-bad-demo
Warning  Unhealthy  (x25)  Readiness probe failed: HTTP probe failed with statuscode: 404
```
- 읽는 포인트:
  - ⚠️ readiness-bad는 **restart=0인데 ready=0** → restart metric만 보면 이 장애를 **완전히 놓침**. ready metric을 따로 봐야 잡힘.
  - ⭐ 원인 evidence = event `Readiness probe failed: statuscode 404`(probe path `/not-ready`가 404). log보다 **event에 먼저** 드러남.

### ④ CPU 압박 — limit까지 차는 CPU rate
```text
# metric: sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="week4-observe",container!="",image!=""}[2m]))
cpu-pressure   0.0918 cores (92m)
readiness-bad  0.0001 cores (0m)
```
- 읽는 포인트:
  - ⭐ cpu-pressure가 **92m** ≈ **limit 100m에 근접** → `while true` loop가 상한까지 씀. CPU limit은 OOM처럼 죽이지 않고 **throttling(속도 제한)** 으로 드러남(W4D1 6교시).
  - ⭐ ready=1(②)이라 "Ready니까 정상"으로 보이지만 CPU는 상한을 치는 중 → **panel 하나로 단정 금지**, CPU+ready+latency 같이.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| metric과 logs/events 역할? | metric=언제/얼마나(시간·범위), logs/events=왜(원인) |
| CrashLoop metric 시그니처? | restart 증가 + ready=0. 원인은 logs --previous / BackOff event |
| readiness 실패가 위험한 이유? | restart 안 늘어서 restart metric만 보면 놓침. ready=0으로 잡아야 함 |
| readiness 원인은 어디서? | event(Readiness probe failed 404). log보다 event에 먼저 |
| CPU 압박은 어떻게 드러나나? | CPU rate가 limit까지, 죽기보다 throttling/latency. ready는 1일 수 있음 |
| increase[5m]=0이면 정상? | 아님. crashloop은 backoff로 간격이 벌어짐 → window 넓히거나 total 확인(여기선 total 7) |
| get pod STATUS만 보면? | readiness-bad가 Running이라 정상처럼 보임 → READY 0/1을 봐야 함 |
| 개발팀에 뭘 전달? | metric 이름만 X. 증상+metric+원인 evidence 세 줄로 |

## notes

### Evidence Note
```markdown
# W4D3S5 failure correlation
- 재현한 장애: crashloop(exit1), readiness-bad(probe 404), cpu-pressure(while true)
- kubectl 증상: crashloop CrashLoopBackOff(7 restarts), readiness-bad 0/1 Running, cpu-pressure 1/1
- PromQL: restarts total crashloop=7 / increase[5m]=0,[15m]=3.1,[30m]=8.15 / ready(true) cpu1 crash0 ready0 / cpu-pressure CPU 92m(limit100m)
- Grafana: Pod restart panel, ready replica, CPU usage
- logs/events 원인: crashloop "intentional restart"+BackOff / readiness "probe failed 404"
- 개발팀 문장 예: "readiness-bad /api 503 → ready replica 0 → probe /not-ready 404 이벤트"
- cleanup: kubectl delete namespace week4-observe (evidence 남긴 뒤)
```

### 증상 → metric → 원인 3줄 연결 (개발팀 전달용)
```markdown
1. 증상: /api 503 증가
2. metric: ready replica 감소
3. 원인 evidence: readiness probe 404 event
---
1. 증상: 응답 지연
2. metric: Pod CPU rate가 limit까지
3. 원인 evidence: cpu loop, limit 낮음(throttling)
```
- ⚠️ metric 이름만 나열하면 개발팀이 못 움직임. **사용자 증상 + Kubernetes evidence**를 함께.

### 원인마다 증거 위치가 다르다 (NPE vs OOM)
`restart 증가`는 "죽었다"까지만 알려줌 — "왜"는 원인별로 **다른 증거**를 봐야 함.
```text
증상(공통): Pod 재시작 / restart 증가   ← metric
   ├─ 원인 NPE?  → 앱 logs (stack trace 남음)
   └─ 원인 OOM?  → describe/event (Reason: OOMKilled, exit 137) — 로그엔 잘 안 나옴
```
| 원인 | 무엇 | 확인 위치 | 로그에 나오나 |
|---|---|---|---|
| NullPointerException | 앱 코드 버그(null 참조) | `kubectl logs` | ✅ stack trace |
| OOMKilled | 컨테이너 memory > limit → 커널 SIGKILL | `kubectl describe`(Reason: OOMKilled, exit 137) | ❌ 급사라 로그 없음 |
- ⚠️ **NPE ≠ OOM**(다른 에러). 단 "둘 다 원인은 증거를 파야 안다"라서 같이 예시로 묶임. NPE=없는 걸 씀(로직), OOM=메모리 바닥남(자원).
- ⚠️ 자바 함정: JVM `OutOfMemoryError`(힙 `-Xmx` 초과, 로그 남음) ≠ K8s `OOMKilled`(컨테이너 limit 초과, 커널이 죽임). `-Xmx`를 컨테이너 limit보다 높게 잡으면 JVM이 에러 던지기 전에 커널이 먼저 죽여 로그 없이 `OOMKilled`만 뜸.

### 용어: throttling (CPU는 죽이지 않고 조인다)
```text
throttling = 쓸 수 있는 양을 강제로 제한해서 느리게 만듦 (목을 조르다 → 흐름 억제)
```
| 자원 | limit 초과 시 |
|---|---|
| memory | **OOMKilled** — 프로세스를 죽임(exit 137) |
| CPU | **throttling** — 안 죽이고 속도만 제한(latency↑) |
- ⭐ cpu-pressure가 92m(limit 100m)인데 `1/1 Running`이었던 이유 = CPU는 죽이지 않고 조여서 느려질 뿐. "안 죽었다 = 정상"이 아님(throttling 중일 수 있음). 비유: 수도꼭지 반쯤 잠금(물 끊긴 게 아니라 찔끔).

### 시나리오별 관찰 순서
```text
CrashLoop:  restart panel → increase(restarts) → get pod → logs --previous → describe events
Readiness:  ready replica ↓ → kube_pod_status_ready → get endpoints → describe readiness event → 503 확인
CPU 압박:   CPU usage → rate(cpu) → top pod → requests/limits → latency/readiness 영향
```

### 오해하기 쉬운 지점
| 오해 | 정리 |
|---|---|
| CPU 높으면 장애 | 지속시간·사용자 영향 필요(정상 batch일 수도) |
| restart 있으면 무조건 문제 | rollout 중 일시 restart일 수도 |
| readiness 실패는 log에 보인다 | event에 먼저 보일 때가 많음 |
| metric 없으면 정상 | target discovery 실패일 수 있음(3교시) |

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| crashloop인데 `increase(restarts[5m])=0` | 지수 backoff로 재시작 간격 벌어짐. window 넓히니 [15m]=3.1,[30m]=8.15, total=7 → crashloop 확실 |
| readiness-bad가 `Running`이라 정상처럼 보임 | READY 0/1 + `kube_pod_status_ready=0` + event `probe failed 404`로 장애 확인. restart는 0이라 restart metric만 보면 놓침 |
| cpu-pressure는 ready=1인데 문제? | CPU 92m로 limit 100m 근접(throttling). ready만 보면 정상, CPU panel 같이 봐야 함 |
| 실습 후 정리 | evidence 남긴 뒤 `kubectl delete namespace week4-observe` (다음 수업 방해 방지) |
