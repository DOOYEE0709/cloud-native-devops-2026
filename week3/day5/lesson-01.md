# 1교시: Day4 요약 + kubectl 운영 루프

## 핵심 정리

### Day4에서 가져올 한 문장
> **Kubernetes는 container를 직접 켜는 명령 모음이 아니라, 원하는 상태를 API Server에 제출하고 control plane이 현재 상태를 맞추게 하는 운영 API다.**
- 오늘부터는 이게 **명령 출력으로 보이는지** 확인:
```text
manifest 작성 → kubectl apply → API Server 저장
  → controller/scheduler/kubelet 동작
  → kubectl get/describe/logs로 현재 상태 확인
```

### 먼저 context 확인하는 이유 (Day4와 동일 강조)
- kubectl은 kubeconfig의 **current-context** 기준으로 API Server에 요청.
- 안 보고 실행하면 **개발용 manifest를 운영 cluster에 적용하는 사고** 가능.
```bash
kubectl config current-context   # 정상: kind-paperclip-week3
kubectl get nodes -o wide        # node Ready면 API Server↔kubelet 정상
```

### namespace = 실습 울타리
- cluster 안의 **논리적 분리 단위**. 오늘은 `week3` namespace 사용.
```bash
kubectl apply -f week3/day5/labs/k8s-first-app/namespace.yaml
kubectl get ns week3
```
- 장점: 조회 범위 제한(`-n week3`), cleanup 단순(`delete namespace`), RBAC 연결(Week4), 관찰 분리.

### 오늘의 kubectl 운영 루프 (모든 실습 이 순서로 반복)
| 단계 | 명령 | 목적 |
|---|---|---|
| 1. 적용 | `kubectl apply -f ...` | 원하는 상태 제출 |
| 2. 목록 | `kubectl get ...` | 상태 요약 |
| 3. 상세 | `kubectl describe ...` | event·selector·image·scheduling |
| 4. 로그 | `kubectl logs ...` | app stdout/stderr |
| 5. 연결 | `kubectl exec` / curlbox | 내부 통신 확인 |
| 6. 복구 | `kubectl rollout undo` / 재적용 | 정상 회복 |
| 7. 정리 | `kubectl delete ...` | 리소스 제거 |

### get vs describe vs logs vs events
- **get = 빠른 상태판** / **describe = 사건 기록**.

| 명령 | 잘 보이는 것 |
|---|---|
| `get` | 이름, READY, STATUS, RESTARTS, AGE |
| `describe` | image, command, env, volume, node, condition, **event** |
| `logs` | container가 남긴 stdout/stderr (`--previous`로 죽은 것도) |
| `events` | cluster가 리소스 처리하며 남긴 이유·메시지 |

### 실패 해석 원칙 = "어디서 멈췄나"
| 멈춘 지점 | 대표 증상 | 먼저 볼 명령 |
|---|---|---|
| image pull | `ImagePullBackOff` | `describe pod` |
| process start | `CrashLoopBackOff` | `logs`, `logs --previous` |
| scheduling | `Pending` | `describe pod` |
| traffic routing | curl 실패, endpoint 없음 | `get svc,endpoints`, `describe svc` |
| rollout | 새 ReplicaSet Ready 안 됨 | `rollout status`, `describe deploy` |

### 한 줄 요약
> **Day5 핵심은 manifest를 많이 쓰는 게 아니라, 적용한 상태가 cluster에서 어떻게 변하는지 kubectl 증거(evidence)로 읽는 것.**

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| current-context는? | `kind-paperclip-week3` (오늘 수업용 kind cluster) |
| context 확인 생략하면? | 엉뚱한 cluster(운영 등)에 manifest를 apply/delete하는 사고 위험 |
| namespace를 쓰는 이유는? | 조회 범위 제한·cleanup 단순·RBAC 연결·관찰 분리 |
| 오늘 가장 자주 쓸 명령은? | apply → get → describe → logs (운영 루프) |
| get vs describe 차이는? | get=빠른 상태판(STATUS 등), describe=event·image·scheduling 등 사건 기록 |

## notes

### `localhost:8080 connection refused` = cluster(또는 context)가 없을 때

**실제 겪은 에러**
```text
kubectl get nodes -o wide
→ Get "http://localhost:8080/api...": dial tcp [::1]:8080: connect: connection refused
  The connection to the server localhost:8080 was refused
```

**원인**
- kubectl이 가리킬 **context가 없으면** 기본값 `localhost:8080`으로 요청 → 거기엔 API Server가 없어서 거부.
- 즉 **cluster가 아직 안 만들어졌거나, 삭제됐거나, current-context가 비어 있는 상태.** (Day4 8교시 troubleshooting의 그 케이스)

**확인 순서**
```bash
kubectl config get-contexts     # 비어 있으면 context 없음
kind get clusters               # 목록 없으면 kind cluster 자체가 없음
docker ps --filter name=paperclip-week3   # node 컨테이너 떠 있나
```

**해결: cluster 생성 (Day4 8교시 그대로)**
```bash
kind create cluster --config week3/day4/labs/kind-cluster/kind-config.yaml
kubectl config current-context  # kind-paperclip-week3 나오면 정상
kubectl get nodes -o wide       # node Ready
```
- 👉 8080 에러가 뜨면 kubectl 명령을 더 쳐봐도 계속 거부됨. **먼저 cluster 생성/context부터** 해결해야 함.

### kubectl 옵션: `-f`, `-o`, `-n`

| 옵션 | 풀네임 | 의미 |
|---|---|---|
| `-f` | `--filename` | **무엇을** 적용할지 (파일/폴더/URL) |
| `-o` | `--output` | 결과를 **어떤 형식으로** 출력할지 |
| `-n` | `--namespace` | 어느 namespace에서 (자주 같이 씀) |

**`-f` (apply -f)**
```bash
kubectl apply -f namespace.yaml   # 이 파일의 manifest 적용
```
- apply는 "원하는 상태 제출", `-f`는 그 상태가 **어디 적혀 있나**를 가리킴.
- `-f ./labs/`(폴더 전체), `-f https://...`(URL), `-f a.yaml -f b.yaml`(여러 개)도 가능.

**`-o` (get -o)**
| `-o` 값 | 출력 |
|---|---|
| (없음) | 기본 요약 (NAME, STATUS, ROLES, AGE, VERSION) |
| `-o wide` | + INTERNAL-IP, OS, KERNEL, **CONTAINER-RUNTIME** 등 |
| `-o yaml` / `-o json` | 리소스 전체 spec/status |
| `-o name` | 이름만 (스크립트용) |
| `-o jsonpath='...'` | 특정 필드만 추출 |
- 💡 `get nodes -o wide`의 CONTAINER-RUNTIME 컬럼에 **`containerd`** 찍힘 → Day4 3교시 "Docker daemon 아니라 containerd"가 실제로 확인되는 곳.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| `localhost:8080 connection refused` | cluster/context 없음 → `kind create cluster`로 생성 후 해결 |
