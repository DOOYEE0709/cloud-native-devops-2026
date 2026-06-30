# 3교시: Pod 장애 읽기

## 핵심 정리

### STATUS는 힌트, 원인은 describe·logs에서
- `kubectl get pods`의 STATUS는 **증상**일 뿐. 원인 분석은 `describe`의 **Events**와 `logs`에서 시작한다.
- 기본 3종 세트:
```bash
kubectl -n week3 get pods
kubectl -n week3 describe pod <pod-name>
kubectl -n week3 logs <pod-name>
```

| STATUS | 의미 | 주 증거 |
|---|---|---|
| `ImagePullBackOff` | image를 가져오지 못함 | `describe pod` event |
| `CrashLoopBackOff` | process가 시작 후 반복 종료 | `logs`, `logs --previous` |
| `Pending` | 아직 node에 배치 안 됨 | scheduling event |
| `Running`이지만 `0/1` | process는 떠도 Ready 아님 | readiness/probe, endpoint |

### k9s = 상태를 빠르게 훑는 보조 도구
- `kubectl`을 **대체하는 게 아님.** cluster 상태를 빠르게 보고 다음 `kubectl` 명령을 고르는 용도.
- ⚠️ **context 주의**: k9s는 현재 kubeconfig context를 봄. 틀리면 엉뚱한 cluster를 본다 → 먼저 `kubectl config current-context` 확인.

```bash
kubectl config current-context   # 먼저 어느 cluster 보는지 확인
k9s
```

| k9s 조작 | 대응 kubectl 감각 |
|---|---|
| `:pods` / `:deploy` / `:svc` | `kubectl get pods/deploy/svc -A` |
| `0` | 모든 namespace 보기 |
| `/crash` | 목록 필터링 |
| `d` / `l` | `kubectl describe ...` / `kubectl logs ...` |

- ⚠️ 증거 남길 땐 **k9s 화면만 캡처하지 말 것.** 재현 가능한 `describe`/`logs` 출력도 함께 남긴다.

### 장애 1: ImagePullBackOff — image를 못 가져옴 (명령)
- 원인: 존재하지 않는 image tag (`nginx:not-a-real-tag`), 또는 private registry 인증·네트워크 문제.

```bash
export NS=week3
export LAB=week3/day5/labs/k8s-first-app
kubectl apply -f "$LAB/pod-bad-image.yaml"
kubectl -n "$NS" get pod bad-image-pod
kubectl -n "$NS" describe pod bad-image-pod   # ← 여기 Events가 핵심
kubectl -n "$NS" delete pod bad-image-pod      # 정리
```

확인할 event:
```text
Failed to pull image
ErrImagePull
ImagePullBackOff
```

| 증거 | 해석 |
|---|---|
| image tag가 없음 | image 이름/tag 오류 |
| registry 인증 실패 | private registry secret 필요 |
| pull timeout | 네트워크 또는 registry 접근 문제 |

- ⚠️ 이 장애는 **`logs`가 핵심이 아님.** container가 시작조차 못 했으므로 application log가 없을 수 있다 → `describe`를 먼저 본다. (실제 출력 → 실습 확인 기록 ①②)

### 장애 2: CrashLoopBackOff — 떴다가 죽음 (명령)
- image pull은 **성공**했지만 container process가 시작 후 종료되는 상황. (`busybox` + `... ; exit 1`)

```bash
kubectl apply -f "$LAB/pod-crashloop.yaml"
kubectl -n "$NS" get pod crashloop-pod
kubectl -n "$NS" logs crashloop-pod
kubectl -n "$NS" logs crashloop-pod --previous || true   # 이전에 죽은 container 로그
kubectl -n "$NS" describe pod crashloop-pod
kubectl -n "$NS" delete pod crashloop-pod                 # 정리
```

| 명령 | 기대 증거 |
|---|---|
| `get pod` | `CrashLoopBackOff`, `RESTARTS` 증가 |
| `logs` | `intentional crash for W3D5` |
| `logs --previous` | 이전에 종료된 container 로그 |
| `describe` | `Back-off restarting failed container` |

- `|| true`의 의미: 명령이 실패해도 다음 실습을 계속하려는 표시. previous log가 아직 없거나 재시작 타이밍이 안 맞으면 `logs --previous`가 실패할 수 있음. **실패를 숨기는 습관으로 쓰면 안 되고**, "타이밍 의존 명령"임을 설명할 때만 사용. (실제 출력 → 실습 확인 기록 ③~⑥)

#### ⚠️ "CrashLoopBackOff" 글자가 바로 안 보이는 이유 (개념)
이 lab의 args는 `echo ...; sleep 2; exit 1` → container가 **매 사이클 2초 살아있다.** 그래서 손으로 `get`을 반복하면 세 국면 중 하나에 걸린다.

| 보이는 STATUS | 그 순간 container 상태 | 언제 |
|---|---|---|
| `Running` (1/1) | `sleep 2` 도는 중 = 살아있음 | 재시작 직후 2초 |
| `Error` (0/1) | `exit 1`로 막 죽은 직후 | 죽은 순간 |
| `CrashLoopBackOff` (0/1) | kubelet이 **다음 재시작까지 대기 중** | back-off 구간 |

- **`CrashLoopBackOff`는 "죽은 상태"가 아니라 "다음 재시작을 기다리는 대기 구간"의 이름**이다.
- `sleep 2`가 Running/Error 국면을 길게 만들어, 초반엔 그 글자를 잡기 어렵다. **back-off 간격은 점점 길어져(10s→20s→…→최대 5분)** RESTARTS가 오를수록 대기창이 길어져 더 잘 보인다.
- 진짜 crash-loop의 증거는 **STATUS 글자가 아니라 `RESTARTS`가 계속 오르는 것.**
- 전이를 직접 보려면: `kubectl -n week3 get pod crashloop-pod -w` (watch).
- 참고: `sleep 2`를 빼면(`echo ...; exit 1`) 즉시 죽어 살아있는 시간이 거의 없으므로 `CrashLoopBackOff`가 대부분 시간 동안 보인다.
- (전이 실제 로그 → 실습 확인 기록 ③)

### Pending은 오늘 깊게 안 본다
- Pending 원인: resource 부족, taint/toleration, volume, scheduling constraint.
- 오늘 목표는 Pod/Deployment/Service 기본 흐름 → Pending은 **Week4 (resource·scheduling·policy)**에서 다시.

### 한 줄 요약
> **ImagePullBackOff는 image를 못 가져온 것, CrashLoopBackOff는 process가 떴다가 죽는 것.**
> STATUS로 증상을 보고, ImagePull은 `describe`, Crash는 `logs`(+`--previous`)로 원인을 찾는다.

## 실습 확인 기록

### ① ImagePullBackOff — get
```text
$ kubectl -n week3 get pod bad-image-pod
NAME            READY   STATUS             RESTARTS   AGE
bad-image-pod   0/1     ImagePullBackOff   0          26s
```

### ② ImagePullBackOff — describe
```text
$ kubectl -n week3 describe pod bad-image-pod
Status:   Pending                         ← STATUS는 ImagePullBackOff인데 Pod Status는 Pending (아직 running 못 함)
Containers:
  nginx:
    Container ID:                          ← 비어 있음 = container가 아예 안 만들어짐
    Image:          nginx:not-a-real-tag
    State:          Waiting
      Reason:       ErrImagePull           ← 시작 못 한 이유
    Ready:          False
    Restart Count:  0                      ← RESTARTS 0 = "떴다가 죽은" 게 아니라 "뜬 적이 없음" (Crash와 결정적 차이)
Conditions:                                ← Ready / ContainersReady = False, 나머지는 True
  Initialized        True
  Ready              False
  ContainersReady    False
  PodScheduled       True                  ← 스케줄은 됐다(node 배치 OK), image에서 막힘
Events:
  Normal   Scheduled  30s              assigned week3/bad-image-pod to paperclip-week3-control-plane
  Normal   Pulling    17s (x2)         Pulling image "nginx:not-a-real-tag"
  Warning  Failed     16s (x2)         Failed to pull image ...: ... nginx:not-a-real-tag: not found  ← 핵심 원인
  Warning  Failed     16s (x2)         Error: ErrImagePull
  Normal   BackOff    3s  (x2)         Back-off pulling image "nginx:not-a-real-tag"
  Warning  Failed     3s  (x2)         Error: ImagePullBackOff
```
- **Container ID 비어 있음 + State `Waiting/ErrImagePull`** → container가 만들어지지도 못함 → `logs`가 없는 이유.
- **Restart Count 0** → CrashLoop(RESTARTS 증가)과 구분되는 결정적 증거. "뜬 적 없음" vs "떴다 죽음".
- **PodScheduled True인데 Ready False** → scheduling은 성공, **image pull 단계**에서 멈춤. (어디서 멈췄나 = 1교시 원칙)
- **Events `not found` → `ErrImagePull` → `BackOff` → `ImagePullBackOff`** → 재시도하다 backoff로 간 흐름이 그대로.

### ③ CrashLoopBackOff — get (STATUS 전이 로그)
```text
# 손으로 반복 조회하면 국면에 따라 STATUS가 바뀐다
$ kubectl -n week3 get pod crashloop-pod
NAME           READY  STATUS            RESTARTS       AGE
crashloop-pod  0/1  Error             4 (2m19s ago)  3m11s   ← 막 죽음
crashloop-pod  1/1  Running           5 (83s ago)    3m12s   ← sleep 2 동안 살아있음
crashloop-pod  0/1  Error             5 (90s ago)    3m19s   ← 또 죽음
crashloop-pod  0/1  CrashLoopBackOff  6 (118s ago)   7m56s   ← back-off 대기 (RESTARTS 오를수록 잘 잡힘)
```
- STATUS가 `Running` ↔ `Error` ↔ `CrashLoopBackOff`로 **번갈아** 보임. **RESTARTS가 계속 증가**하는 게 공통 신호.
- `CrashLoopBackOff`는 RESTARTS가 오를수록(back-off 간격이 길어져) 더 잘 잡힌다. (개념은 핵심 정리 "글자가 안 보이는 이유" 참고)

### ④ CrashLoopBackOff — logs
```text
$ kubectl -n week3 logs crashloop-pod
intentional crash for W3D5          ← args의 echo가 실제로 실행됨 = image pull/시작은 성공
```

### ⑤ CrashLoopBackOff — logs --previous (실패 사례)
```text
$ kubectl -n week3 logs crashloop-pod --previous || true
unable to retrieve container logs for containerd://623c0a9b...   ← 이번엔 previous 로그를 못 가져옴
```
- 바로 이 장면이 `|| true`가 필요한 이유. previous container 로그가 GC됐거나 타이밍이 안 맞으면 이렇게 **실패**한다. `|| true` 덕에 실습이 멈추지 않고 다음 명령으로 넘어감.

### ⑥ CrashLoopBackOff — describe
```text
$ kubectl -n week3 describe pod crashloop-pod
Status:   Running                    ← Pod는 Running인데 container는 죽는 중 (READY 0/1)
Containers:
  crash:
    Command:  sh -c
    Args:     echo "intentional crash for W3D5"; sleep 2; exit 1   ← exit 1 = 일부러 비정상 종료
    State:          Terminated        ← 현재 container: 종료됨
      Reason:       Error
      Exit Code:    1                  ← 0이 아님 = 실패 종료
      Started: 09:43:26  Finished: 09:43:28
    Last State:     Terminated         ← 직전 container도 같은 패턴
      Reason:       Error   Exit Code: 1
      Started: 09:43:13  Finished: 09:43:15
    Ready:          False
    Restart Count:  2                  ← 계속 증가 (ImagePull의 0과 대비)
Events:
  Normal   Pulled   ...  Successfully pulled image "busybox:1.36"   ← image는 정상 pull됨
  Normal   Created  18s (x3 over 34s)  Container created            ← (x3) 세 번 다시 만들어짐
  Normal   Started  18s (x3 over 34s)  Container started
  Warning  BackOff  16s (x2 over 28s)  Back-off restarting failed container crash   ← 핵심
```
- **Image `Pulled`/`Started` 정상** → ImagePullBackOff와 정반대. 시작은 됐고 **process가 죽는** 문제.
- **State Terminated `Exit Code: 1`** + **Last State도 동일** → 한 번이 아니라 **반복** 종료 패턴.
- **Restart Count 2 (증가 중)** → "떴다 죽음"의 증거. (장애1의 Restart Count 0과 짝지어 기억)
- **`Created`/`Started` (x3)** → 같은 container를 세 번 다시 만든 흔적 = self-healing이 재시작을 시도 중.
- **`Back-off restarting failed container`** → 너무 빨리 죽어서 재시작 간격을 늘리는 backoff 상태.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| ImagePullBackOff vs CrashLoopBackOff 차이는? | 전자는 image를 못 가져옴(시작 전), 후자는 떴다가 process가 죽음(시작 후 반복 종료) |
| ImagePullBackOff는 logs vs describe 중 뭘 먼저? | describe의 Events. container가 안 떠서 application log가 없을 수 있음 |
| CrashLoopBackOff에서 `logs --previous`가 필요한 때는? | 현재 container가 또 죽어 로그가 비거나, 직전에 죽은 container의 로그를 봐야 할 때 |
| `\|\| true`를 붙이는 이유는? | 타이밍상 previous log가 없을 수 있어 실패해도 다음 실습 진행. 실패 은폐용 아님 |
| k9s는 kubectl을 대체하나? | 아니다. 상태를 빠르게 훑고 다음 kubectl 명령을 고르는 보조 도구. context 확인 필수 |

## notes

### 장애 증거 기록 템플릿
```markdown
## Pod Failure Note
- resource:
- status:
- first command:
- describe event reason:
- log message:
- suspected layer: image pull / process start / scheduling / network
- recovery action:
```

### Evidence Note
```markdown
# W3D5S3 Pod Failure
- ImagePullBackOff event:
- CrashLoopBackOff log:
- RESTARTS 변화:
- `logs`보다 `describe`를 먼저 봐야 하는 경우:
- `logs --previous`가 필요한 경우:
- k9s로 확인한 resource와 대응 kubectl 명령:
```

### 복구 전에 증거부터
- 실패 상태를 바로 지우거나 고치지 말고, **먼저 증거를 남긴다** (`describe`/`logs` 출력, RESTARTS 변화).
- 증거 없이 복구하면 "왜 깨졌는지"가 사라져 같은 장애가 반복돼도 원인 추적이 어려워짐. (2교시 "한 번에 하나씩 바꾸고 확인" 원칙과 연결)

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
