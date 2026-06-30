# 5교시: Deployment Manifest 해부

## 핵심 정리

### 전체 manifest 한눈에
```yaml
apiVersion: apps/v1        # Deployment는 apps API group
kind: Deployment
metadata:
  name: hello-web
  namespace: week3
  labels:
    app: hello-web
spec:
  replicas: 2              # desired state: Pod 2개 유지
  selector:
    matchLabels:
      app: hello-web       # 관리할 Pod 찾는 기준
  template:                # 새로 만들 Pod의 설계도
    metadata:
      labels:
        app: hello-web     # 새 Pod에 붙일 label (selector와 일치해야)
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

### apiVersion / kind — Pod는 `v1`, Deployment는 `apps/v1`
| 필드 | 설명 |
|---|---|
| `apiVersion: apps/v1` | Deployment는 `apps` API group에 속함 |
| `kind: Deployment` | 만들 resource 종류 |

- ⚠️ Pod는 `v1`(core group)인데 Deployment는 `apps/v1`. **object마다 API group/version이 다를 수 있다.**

### metadata — 이름·위치·label
| 필드 | 설명 |
|---|---|
| `name` | namespace 안에서 resource 이름 |
| `namespace` | 배포 위치 |
| `labels` | 조회·grouping·운영 분류용 metadata |

```bash
kubectl -n week3 get deployment hello-web --show-labels
kubectl -n week3 get pods -l app=hello-web
```

### spec.replicas — 앱 전체 Pod 개수 (node별 아님)
- `replicas: 2` = "cluster 전체에서 hello-web Pod 2개 유지" desired state.
```text
replicas: 3
= cluster 전체에서 hello-web Pod를 3개 유지하고 싶다
!= node마다 3개씩 띄운다
```

```bash
# scale은 live object를 직접 바꿈 (manifest와 live state가 갈릴 수 있음 → Argo CD에서 다시)
kubectl -n week3 scale deployment hello-web --replicas=3
kubectl -n week3 get deploy,pod -l app=hello-web
kubectl -n week3 scale deployment hello-web --replicas=2   # 원복
```
- ⚠️ `scale`은 **manifest가 아니라 live state**를 바꾼다. Git/manifest 기준과 cluster live가 어긋나는 문제 = **drift** (Argo CD 주제).
- Deployment를 scale하면 아래 ReplicaSet의 desired count도 함께 바뀜:

| 리소스 | 왜 count가 보이나 |
|---|---|
| Deployment | 운영자가 선언한 배포 단위의 desired replica |
| ReplicaSet | 특정 Pod template에 대해 실제 Pod 수를 맞춤 |
| Pod | Scheduler가 node에 배치한 실행 단위 |

- rollout 때는 Deployment 하나 아래 ReplicaSet이 여러 개 보일 수 있음. 모두 같은 수가 아니라, Deployment가 전체 desired 기준으로 **새/옛 ReplicaSet 수를 조정**. (4교시 연결)

### ⭐ selector와 template label — controller 소유 관계의 핵심
```yaml
selector:
  matchLabels:
    app: hello-web        # ← 관리할 Pod 찾는 기준
template:
  metadata:
    labels:
      app: hello-web      # ← 새로 만들 Pod에 붙이는 label
```

| 값 | 역할 |
|---|---|
| `selector.matchLabels` | Deployment가 **관리할 Pod를 찾는** 기준 |
| `template.metadata.labels` | Deployment가 **새로 만들 Pod에 붙이는** label |

- 이 둘이 어긋나면 controller가 원하는 Pod를 못 찾는다.
- ⚠️ Kubernetes는 **Deployment 생성 시 selector/template 불일치를 강하게 막음.** 하지만 **Service selector 불일치는 쉽게 만들어짐** → 6교시 Service endpoint 장애로 확인.

### template.spec — 새 Pod의 spec
| 필드 | 설명 |
|---|---|
| `containers[].name` | container 이름. rollout `set image`에서 사용 |
| `containers[].image` | 실행 image |
| `containerPort` | container 사용 port 문서화 |

```bash
# 현재 image만 뽑기 (jsonpath)
kubectl -n week3 get deployment hello-web -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

### live state vs manifest 비교
```bash
kubectl -n week3 get deployment hello-web -o yaml   # live에는 내가 안 쓴 필드도 많음
kubectl -n week3 describe deployment hello-web
```

| live field | 의미 |
|---|---|
| `status` | 현재 상태 |
| `resourceVersion` | API Server 저장 버전 |
| `managedFields` | 어떤 client가 어떤 field를 관리했는지 |
| `conditions` | Available, Progressing 등 |

- 모든 field를 외우지 않는다. 오늘은 **`metadata` / `spec` / `status` / `events`를 구분**하는 게 목표.

### 한 줄 요약
> **Deployment manifest의 핵심은 `replicas`·`selector`·`template`이며, selector와 template label이 controller의 소유 관계를 만든다.**

## 실습 확인 기록

### ① scale로 replicas 늘렸다 줄이기 (2 → 3 → 2)
```text
$ kubectl -n week3 scale deployment hello-web --replicas=3
deployment.apps/hello-web scaled

$ kubectl -n week3 get deploy,pod -l app=hello-web
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hello-web   3/3     3            3           52s

NAME                             READY   STATUS    RESTARTS   AGE
pod/hello-web-74d95c87c8-9hwmq   1/1     Running   0          52s
pod/hello-web-74d95c87c8-d9xv8   1/1     Running   0          52s
pod/hello-web-74d95c87c8-gpglv   1/1     Running   0          21s    ← 새로 추가된 3번째 (AGE 21s로 더 어림)

$ kubectl -n week3 scale deployment hello-web --replicas=2
deployment.apps/hello-web scaled

$ kubectl -n week3 get deploy,pod -l app=hello-web
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hello-web   2/2     2            2           70s

NAME                             READY   STATUS    RESTARTS   AGE
pod/hello-web-74d95c87c8-9hwmq   1/1     Running   0          70s
pod/hello-web-74d95c87c8-d9xv8   1/1     Running   0          70s    ← gpglv(방금 만든 것)가 제거됨
```
- 읽는 포인트:
  - **scale=3 → Pod가 즉시 3개**, READY `3/3`. desired state를 바꾸자 controller가 맞춤.
  - **새 Pod(`gpglv`)의 AGE 21s** = 나머지(52s)보다 어림 → 방금 추가된 것. **RS 해시(`74d95c87c8`) 동일** → 같은 template, 개수만 늘림.
  - **scale=2로 줄이면 gpglv 제거** → 가장 최근/우선순위 낮은 Pod부터 정리. READY `2/2`로 수렴.
  - ⚠️ 이건 **live state 직접 변경**(manifest의 `replicas: 2`와 일시적으로 어긋남 = drift). 수업용으로만 짧게.

### ② scale은 Deployment → ReplicaSet으로 전파된다
```text
$ kubectl -n week3 scale deployment hello-web --replicas=3
deployment.apps/hello-web scaled

$ kubectl -n week3 get deploy hello-web
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
hello-web   3/3     3            3           12m

$ kubectl -n week3 get rs -l app=hello-web
NAME                   DESIRED   CURRENT   READY   AGE
hello-web-74d95c87c8   3         3         3       13m
```
- 읽는 포인트:
  - **Deployment를 3으로 scale → ReplicaSet `DESIRED`도 3**으로 따라감. Deployment가 자기가 소유한 RS의 desired를 갱신한 것.
  - 즉 내가 만지는 건 **Deployment 하나**인데, 실제 Pod 개수를 맞추는 일은 **ReplicaSet**이 한다. (4교시 소유 사슬: Pod ← RS ← Deployment)
  - ⚠️ 반대로 **RS를 직접 scale하면** Deployment가 desired로 다시 덮어씀 → 항상 **Deployment를 바꿔야** 한다. (4교시 notes "RS 직접 변경 금지")

### ③ 현재 image만 뽑기 (jsonpath)
```text
$ kubectl -n week3 get deployment hello-web -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
nginx:1.27
```
- `-o jsonpath`로 **필요한 한 필드만** 추출. 전체 yaml을 안 보고 image만 확인할 때 유용 (스크립트·rollout 확인에 자주 씀).

### ④ live yaml — 내가 안 쓴 필드가 잔뜩 (get -o yaml)
```text
$ kubectl -n week3 get deployment hello-web -o yaml
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
    kubectl.kubernetes.io/last-applied-configuration: | {...}   ← 마지막 apply한 manifest 원본 보관
  generation: 5                  ← spec이 바뀐 횟수 (scale 5번 등)
  resourceVersion: "19987"       ← API Server 저장 버전 (변경마다 증가)
  uid: 8910d978-...              ← 이 object의 전역 고유 id
spec:
  replicas: 2                    ← 지금은 manifest와 일치 (scale 원복됨)
  revisionHistoryLimit: 10       ← 보관할 rollout 이력 수
  strategy:
    rollingUpdate: { maxSurge: 25%, maxUnavailable: 25% }   ← 기본 rollout 전략 (내가 안 써도 채워짐)
    type: RollingUpdate
  template:
    spec:
      containers:
      - image: nginx:1.27
        imagePullPolicy: IfNotPresent   ← 기본값 자동 주입
        ...
status:                          ← ⭐ 내가 쓰는 게 아니라 cluster가 채우는 "현재 상태"
  availableReplicas: 2
  readyReplicas: 2
  replicas: 2
  observedGeneration: 5
  conditions:
  - type: Progressing  status: "True"  reason: NewReplicaSetAvailable
  - type: Available    status: "True"  reason: MinimumReplicasAvailable
```
- 읽는 포인트:
  - **내가 쓴 건 `spec`의 일부뿐** → live에는 default(`imagePullPolicy`, `strategy`, `revisionHistoryLimit` 등)와 운영 metadata(`uid`, `resourceVersion`, `generation`)가 잔뜩 추가됨.
  - **`status`는 내가 쓰는 게 아니라 cluster가 채움** = "지금 실제 상태". `spec`(desired) vs `status`(actual)의 구분이 핵심.
  - **`last-applied-configuration`** = 내가 마지막으로 apply한 manifest 원본을 annotation에 보관 → `kubectl apply`가 3-way merge로 변경분 계산할 때 사용.

### ⑤ describe deployment — 사람이 읽기 좋은 요약 + Events
```text
$ kubectl -n week3 describe deployment hello-web
Selector:               app=hello-web
Replicas:               2 desired | 2 updated | 2 total | 2 available | 0 unavailable
StrategyType:           RollingUpdate
Conditions:
  Progressing    True    NewReplicaSetAvailable
  Available      True    MinimumReplicasAvailable
NewReplicaSet:   hello-web-74d95c87c8 (2/2 replicas created)
Events:
  Normal  ScalingReplicaSet  13m              Scaled up   replica set ... from 0 to 2
  Normal  ScalingReplicaSet  66s (x2 over 13m) Scaled up   replica set ... from 2 to 3
  Normal  ScalingReplicaSet  35s (x2 over 12m) Scaled down replica set ... from 3 to 2
```
- 읽는 포인트:
  - **`-o yaml`은 전체 raw**, **`describe`는 사람이 읽기 좋은 요약 + Events**. 같은 object를 보는 두 시선.
  - **Replicas 한 줄**(`2 desired | 2 updated | 2 total | 2 available`)에 rollout 상태가 압축됨.
  - **`NewReplicaSet: ...74d95c87c8`** = 현재 활성 RS. rollout 전이면 `OldReplicaSets`도 같이 보임.
  - **Events에 scale 이력**(`0→2`, `2→3`, `3→2`)이 그대로 → 아까 ①②에서 한 scale이 여기 기록됨. **누가 무엇을 했는지 추적 가능.**

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Pod와 Deployment의 apiVersion이 다른 이유는? | Pod=`v1`(core), Deployment=`apps/v1`. object마다 API group/version이 다름 |
| `replicas: 3`의 의미는? | cluster 전체에서 Pod 3개 유지. node마다 3개가 아님 |
| `scale` 명령이 바꾸는 것은? | manifest가 아니라 live state. Git 기준과 어긋나면 drift (Argo CD 주제) |
| selector와 template label이 하는 일은? | selector=관리할 Pod 찾는 기준, template label=새 Pod에 붙이는 이름표. 둘이 controller 소유 관계를 만듦 |
| Deployment 생성 시 selector 불일치는? | Kubernetes가 강하게 막음. 단 Service selector 불일치는 쉽게 발생 → 6교시 장애 |
| live yaml과 manifest의 차이는? | live엔 status·resourceVersion·managedFields·conditions 등 내가 안 쓴 필드가 추가됨 |

## notes

### Evidence Note
```markdown
# W3D5S5 Manifest
- apiVersion:
- kind:
- replicas:
- selector:
- template label:
- current image:
- live status에서 확인한 condition:
```

### manifest(desired) vs live state(actual) — drift의 씨앗
- manifest = 내가 **원하는 상태**(Git에 저장). live = cluster에 **실제로 있는 상태**.
- `scale`, `edit`, `kubectl set image` 같은 명령은 live를 직접 바꿔 manifest와 어긋나게 만든다 = **drift**.
- 그래서 GitOps(Argo CD)는 "Git의 manifest가 항상 정답"으로 두고 live가 어긋나면 다시 맞춘다. (오늘은 개념만, 깊게는 나중)

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
