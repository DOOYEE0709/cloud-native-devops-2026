# 4교시: Deployment가 필요한 이유

## 핵심 정리

### 직접 Pod의 운영 한계 → Deployment로
- 2교시 `hello-pod`는 학습용으론 좋지만 **운영 배포 단위로는 부족.**

| 운영 요구 | 직접 Pod의 한계 |
|---|---|
| 같은 앱 2개 이상 | manifest 여러 개를 직접 관리 |
| 죽은 Pod 복구 | 다시 만들어줄 controller 없음 |
| image 교체 | rollout/history/undo 약함 |
| 서비스 연결 | label·endpoint 관리 불안정 |
| 배포 상태 확인 | `rollout status` 같은 배포 단위 상태 없음 |

- Deployment는 **Pod template + replica 수**를 "원하는 상태(desired state)"로 선언 → controller가 그 상태를 유지.

```text
Deployment
  └─ ReplicaSet
       ├─ Pod 1
       └─ Pod 2
```

### ⚠️ Deployment replica vs ReplicaSet replica (가장 헷갈리는 지점)
- 둘 다 replica 수가 있지만 **어느 쪽도 "node별 개수"가 아니다.**

| 항목 | count 의미 | node와의 관계 |
|---|---|---|
| Deployment `spec.replicas` | 이 앱 version을 **최종 몇 개** 유지할지 (운영자 의도) | node 직접 안 고름 |
| ReplicaSet `spec.replicas` | **특정 Pod template**으로 Pod 몇 개 유지할지 (실행) | node 직접 안 고름 |
| Scheduler | 만들어진 Pod를 **어느 node**에 둘지 | node 배치 담당 |
| DaemonSet | 보통 **node마다 1개** | node 수와 강하게 연결 |

```text
Deployment의 replica   = 운영자가 원하는 앱 전체 개수
ReplicaSet의 replica   = 현재 Pod template 기준 유지할 Pod 개수
node별 개수            = Scheduler / DaemonSet / scheduling 정책의 영역
```

- ⚠️ kind 단일 node에선 Pod가 **같은 node에 몰려 보임** → ReplicaSet이 node별 배치를 한 게 아니라, **고를 node가 하나뿐**이라 그런 것.
- node마다 1개씩 띄우는 건 Deployment가 아니라 **DaemonSet** (로그 수집 agent, node exporter, CNI agent, CSI node plugin 등).

### rolling update 때 ReplicaSet count가 핵심
- 새 template이 생기면 **새 ReplicaSet**이 만들어지고, Deployment가 양쪽 count를 조절:

```text
Deployment desired = 2
old ReplicaSet: 2 → 1 → 0
new ReplicaSet: 0 → 1 → 2
```

### Deployment 배포 & 읽기 (명령)
```bash
export NS=week3
export LAB=week3/day5/labs/k8s-first-app
kubectl apply -f "$LAB/deployment.yaml"
kubectl -n "$NS" rollout status deployment/hello-web
kubectl -n "$NS" get deploy,rs,pod -l app=hello-web -o wide
```

| 출력 컬럼 | 해석 |
|---|---|
| Deployment `READY 2/2` | 원하는 앱 replica 2개 중 2개 Ready |
| ReplicaSet `DESIRED 2` | 이 template의 ReplicaSet이 Pod 2개 유지 |
| Pod `NODE` | Scheduler가 각 Pod를 배치한 node |

### Deployment가 유지하는 핵심 필드
```yaml
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-web        # 관리할 Pod 찾는 기준
  template:
    metadata:
      labels:
        app: hello-web      # 새로 만들 Pod에 붙일 label
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
```
- ⚠️ **`selector.matchLabels`와 `template.labels`가 어긋나면** Deployment가 Pod를 제대로 소유 못 함 (Week4 Service/Ingress 장애에서 반복 등장).

### Self-healing & owner 관계 (명령)
```bash
# self-healing: Pod 하나 지워도 ReplicaSet이 다시 채움
POD_NAME=$(kubectl -n "$NS" get pod -l app=hello-web -o jsonpath='{.items[0].metadata.name}')
kubectl -n "$NS" delete pod "$POD_NAME"
kubectl -n "$NS" get pod -l app=hello-web -w   # 흐름 보고 Ctrl+C

# owner 관계: Pod의 직접 주인이 누구인지
kubectl -n "$NS" get pod -l app=hello-web -o jsonpath='{range .items[*]}{.metadata.name}{" <- "}{.metadata.ownerReferences[0].kind}{"/"}{.metadata.ownerReferences[0].name}{"\n"}{end}'
```
- Pod 삭제 → desired(2) 맞추려 **새 Pod 생성**. 죽은 걸 살리는 게 아니라 새로 만든다.
- Pod의 직접 주인은 Deployment가 아니라 **ReplicaSet**. 소유 사슬: **Pod ← ReplicaSet ← Deployment**.

### 한 줄 요약
> **Deployment는 Pod를 직접 실행하는 방법이 아니라, Pod template과 replica 수를 원하는 상태로 유지하는 controller 단위다.**

## 실습 확인 기록

### ① 배포 → rollout status
```text
$ kubectl apply -f deployment.yaml
deployment.apps/hello-web created

$ kubectl -n week3 rollout status deployment/hello-web
deployment "hello-web" successfully rolled out      ← 2개가 다 Ready 될 때까지 기다렸다 성공
```

### ② get deploy,rs,pod -o wide (3계층 한눈에)
```text
$ kubectl -n week3 get deploy,rs,pod -l app=hello-web -o wide
NAME                        READY  UP-TO-DATE  AVAILABLE  AGE  CONTAINERS  IMAGES      SELECTOR
deployment.apps/hello-web   2/2    2           2          7s   nginx       nginx:1.27  app=hello-web

NAME                                   DESIRED  CURRENT  READY  AGE  ...  SELECTOR
replicaset.apps/hello-web-74d95c87c8   2        2        2      7s   ...  app=hello-web,pod-template-hash=74d95c87c8

NAME                             READY  STATUS   RESTARTS  AGE  IP          NODE
pod/hello-web-74d95c87c8-9lb4k   1/1    Running  0         7s   10.244.0.8  paperclip-week3-control-plane
pod/hello-web-74d95c87c8-bvttf   1/1    Running  0         7s   10.244.0.9  paperclip-week3-control-plane
```
- **3계층**: Deployment(`hello-web`) → ReplicaSet(`hello-web-74d95c87c8`) → Pod 2개. Pod 이름 = `<deploy>-<rs hash>-<random>`.
- **`pod-template-hash=74d95c87c8`** = ReplicaSet name 해시와 동일 → "어느 template의 Pod인지" 묶는 키. rolling update 때 새 해시 = 새 RS.
- **두 Pod 같은 NODE** → kind 단일 node라 Scheduler가 고를 node가 하나뿐. ReplicaSet의 node별 배치 아님.
- **Deployment `UP-TO-DATE 2`** = 최신 template을 쓰는 replica 2개 (rollout 진행도 지표).

### ③ Deployment vs ReplicaSet count 나란히
```text
$ kubectl -n week3 get deploy hello-web
NAME        READY  UP-TO-DATE  AVAILABLE  AGE
hello-web   2/2    2           2          24s

$ kubectl -n week3 get rs -l app=hello-web
NAME                   DESIRED  CURRENT  READY  AGE
hello-web-74d95c87c8   2        2        2      36s
```
- Deploy `READY 2/2`(원하는 앱 개수) ↔ RS `DESIRED 2`(이 template Pod 개수) **일치** → 단일 version이라 같다. rolling update 중엔 old/new RS로 갈려 달라진다.

### ④ self-healing: Pod 삭제 → 자동 재생성
```text
$ kubectl -n week3 delete pod "$POD_NAME"
pod "hello-web-74d95c87c8-9lb4k" deleted from week3 namespace   ← 9lb4k 삭제

$ kubectl -n week3 get pod -l app=hello-web -w
NAME                         READY   STATUS    RESTARTS   AGE
hello-web-74d95c87c8-bvttf   1/1     Running   0          13m    ← 안 지운 기존 Pod (유지)
hello-web-74d95c87c8-vbvfw   1/1     Running   0          5s     ← ReplicaSet이 새로 만든 Pod
```
- **9lb4k 삭제 → vbvfw 생성** = 죽은 Pod를 살린 게 아니라 desired(2) 맞추려 **새로 만든** 것 (이름 다름).
- **AGE 차이**(`13m` vs `5s`)가 증거. **RS 해시 동일** → 같은 template, self-healing은 template 안 바꿈.
- 직접 Pod였다면 지운 순간 끝. ReplicaSet 덕에 **2개로 자동 복구**.

### ⑤ owner 관계 확인
```text
$ kubectl -n week3 get pod -l app=hello-web -o jsonpath='{range .items[*]}{.metadata.name}{" <- "}{.metadata.ownerReferences[0].kind}{"/"}{.metadata.ownerReferences[0].name}{"\n"}{end}'
hello-web-74d95c87c8-bvttf <- ReplicaSet/hello-web-74d95c87c8
hello-web-74d95c87c8-vbvfw <- ReplicaSet/hello-web-74d95c87c8
```
- 두 Pod의 owner가 Deployment가 아니라 **`ReplicaSet/hello-web-74d95c87c8`** → Pod 직접 주인은 ReplicaSet.
- bvttf(기존)·vbvfw(self-healing 새 Pod) owner **동일** → self-healing 주체가 ReplicaSet임을 확증.
- 소유 사슬: **Pod ← ReplicaSet(`74d95c87c8`) ← Deployment(`hello-web`)**.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 직접 Pod 대신 Deployment를 쓰는 이유는? | self-healing·replica 유지·rollout/undo·서비스 연결을 controller가 선언적으로 보장 |
| Deployment replica와 ReplicaSet replica 차이는? | 전자는 원하는 앱 전체 개수, 후자는 특정 template 기준 유지할 Pod 개수. 둘 다 node별 개수 아님 |
| node별 개수는 누가 정하나? | ReplicaSet이 아니라 Scheduler(배치) / DaemonSet(node마다 1개) |
| kind에서 Pod가 한 node에 몰리는 이유는? | node가 하나뿐이라 Scheduler가 고를 node가 하나뿐. 배치 정책 결과 아님 |
| Pod의 owner는? | ReplicaSet (그 위가 Deployment). Deployment가 Pod를 직접 소유하지 않음 |
| selector와 template label이 어긋나면? | Deployment가 Pod를 제대로 소유 못 함 → Service/Ingress 장애로 이어짐 |

## notes

### Evidence Note
```markdown
# W3D5S4 Deployment
- deployment READY:
- replica count:
- ReplicaSet name:
- deleted Pod:
- newly created Pod:
- self-healing evidence:
```

### kubectl 명령 토막내기 (`-n`, `get`, `rs`, `-l`)
```bash
kubectl  -n week3  get  rs  -l app=hello-web
   │        │       │   │       │
 도구   namespace  동작 대상   label 필터
```

| 토막 | 뜻 | 풀어서 |
|---|---|---|
| `kubectl` | Kubernetes 조작 CLI | cluster에 명령 보내는 도구 |
| `-n week3` | `--namespace` 축약 | "week3 라는 **방** 안에서 찾아라". 생략하면 `default` namespace |
| `get` | 동작(verb) = 조회 | 목록을 표로 보여줌 (생성=`apply`, 삭제=`delete`) |
| `rs` | 대상 resource = ReplicaSet | 축약형. `deploy`=Deployment, `po`=Pod, `svc`=Service |
| `-l app=hello-web` | `--selector`(label) 필터 | label `app=hello-web`인 것만 추림 |

#### `app=hello-web`은 label(이름표) 하나 — `key=value`
- deployment.yaml에서 Pod에 붙인 이름표다.
```yaml
template:
  metadata:
    labels:
      app: hello-web      # ← 이 Pod들에 "app=hello-web" 이름표를 붙임
```
- 그래서 `-l app=hello-web` = **"그 이름표 붙은 것만 보여줘"**.

#### 이름 지정 vs label 필터 (두 명령의 차이)
```bash
kubectl -n week3 get deploy hello-web        # ① 이름이 'hello-web'인 Deployment 1개 (이름으로 콕 집음)
kubectl -n week3 get rs -l app=hello-web     # ② label이 app=hello-web인 ReplicaSet 전부 (label로 필터)
```
- **①** `hello-web`은 resource **이름**(고정) → 이름으로 직접 지정.
- **②** ReplicaSet 이름은 `hello-web-74d95c87c8`처럼 **해시가 붙어 매번 바뀜** → 이름을 미리 알 수 없으니 **label로 필터**가 편하다.
- ⚠️ `hello-web`(이름)과 `app=hello-web`(label)은 글자가 비슷해도 **다른 것.** 하나는 resource 식별 이름, 하나는 key=value 이름표.

> 한 줄: `-n`=어느 방, `get`=조회, `rs`=ReplicaSet, `-l app=hello-web`=그 이름표 붙은 것만. 이름이 고정이면 이름으로, 해시로 바뀌면 label로 찾는다.

### ReplicaSet의 replicas를 직접 바꿔도 Deployment 값으로 돌아간다
- ReplicaSet에서 `spec.replicas`를 직접 변경해도 **곧 Deployment의 `spec.replicas`로 되돌아간다.** ReplicaSet이 Deployment의 하위이기 때문.
- 다만 "하위라서"를 정확히 풀면 → **상위 Deployment controller가 자기가 소유한 ReplicaSet을 끊임없이 reconcile(원하는 상태로 수렴)하기 때문**이다.

```bash
# RS를 직접 5로 바꿔도
kubectl -n week3 scale rs <hello-web-xxxxx> --replicas=5
# 잠시 후 다시 보면 Deployment의 desired(2)로 복구됨
kubectl -n week3 get rs -l app=hello-web
```

동작 흐름:
1. **소유 관계(ownerReference)**: RS에 `ownerReferences: Deployment/hello-web`가 박혀 있어 Deployment가 그 RS를 "내 것"으로 인식.
2. **reconcile loop**: Deployment controller가 계속 "내 desired replicas == 내 RS의 replicas?"를 비교.
3. **drift 교정**: 누가 RS를 5로 바꾸면 desired와 어긋남(drift) → controller가 다시 2로 덮어씀.

| 조작 | 결과 |
|---|---|
| `scale deployment/hello-web` | RS로 정상 전파 (정상 경로) |
| `scale rs <...>` 직접 변경 | Deployment가 다시 덮어씀 (drift 취급) |
| RS 직접 변경이 안 덮어써짐 | 그 RS가 고아(orphan)이거나 Deployment 없이 만든 독립 RS일 때뿐 |

> 핵심은 "하위라는 계층" 자체가 아니라, 그 계층을 유지하는 **reconciliation(원하는 상태로 계속 수렴)**. 이게 Kubernetes의 desired state 모델 그 자체다. 그래서 운영에서 **RS를 직접 scale하면 안 된다** — 바꾸려면 항상 Deployment를 바꾼다.

### replica가 노드에 어떻게 흩어지나 (스케줄러 분산)
- **질문**: replicas=2면 서로 다른 노드에 1개씩 생기나? "선호도 지정 안 하면 균등"이 맞나?
- **답**: 보통 1개씩 흩어진다. 단 **"균등"은 보장이 아니라 기본적으로 그렇게 되도록 점수를 주는 soft(best-effort)**다.

동작:
- kube-scheduler는 노드마다 **점수(score)**를 매겨 가장 높은 노드를 고른다. 그 점수 항목 중 하나가 **"같은 그룹 Pod를 여러 노드에 퍼뜨리기"**(기본 `PodTopologySpread`).
- 그래서 아무 설정 없어도 같은 Deployment Pod를 노드·zone에 퍼뜨리려는 **기본 점수**가 작동 → replicas=2면 보통 노드 2개에 1개씩.

⚠️ 하지만 soft라서 **항상 균등은 아님.** 아래가 더 세면 한 노드에 몰릴 수 있다:

| 몰릴 수 있는 이유 | 설명 |
|---|---|
| 다른 노드 resource 부족 | 여유 있는 노드로 둘 다 감 |
| taint/cordon | 다른 노드가 스케줄 금지 상태 |
| nodeSelector/affinity | 특정 노드로 유도됨 |
| image locality | 이미 image 있는 노드 점수 높음 |

**무조건 1개씩**을 원하면 → hard 제약으로 명시:
```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule   # ScheduleAnyway=soft / DoNotSchedule=hard(못 지키면 Pending)
    labelSelector:
      matchLabels:
        app: hello-web
```
- 또는 `podAntiAffinity`로 같은 효과.

⚠️ **지금 실습(kind)은 control-plane 1개뿐** → 고를 노드가 하나라 **항상 같은 노드.** lesson-04 ②에서 두 Pod가 같은 node에 찍힌 이유. 분산을 보려면 kind를 **multi-node**(worker 추가)로 만들어야 한다.

> 한 줄: **기본은 "퍼뜨리려는 soft 점수"라 보통 1개씩 흩어지지만 보장은 아님. 강제하려면 `topologySpreadConstraints`/`podAntiAffinity`로 hard 지정.**

### 3교시 장애와 연결
- 3교시에서 본 self-healing(CrashLoopBackOff의 자동 재시작)은 **kubelet의 container 재시작**.
- 4교시 self-healing(Pod 삭제 후 재생성)은 **ReplicaSet의 Pod 재생성**.
- 둘은 레벨이 다르다: **container 재시작(kubelet)** vs **Pod 재생성(controller)**.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
