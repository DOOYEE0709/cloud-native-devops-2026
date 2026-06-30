# 2교시: 첫 Pod 실행

## 핵심 정리

### Pod manifest 4대 필드
```yaml
apiVersion: v1          # 이 object의 API version
kind: Pod               # 만들 resource 종류
metadata:
  name: hello-pod       # cluster 내 식별 이름
  namespace: week3      # 들어갈 namespace
  labels: { app: hello-pod }   # Service/조회/분류용 key-value
spec:
  containers:
    - name: nginx
      image: nginx:1.27       # 실행할 image
      ports:
        - containerPort: 80   # container가 80 쓴다고 "문서화"
```
- **4대 구조**: `apiVersion`(어느 API) / `kind`(무엇을) / `metadata`(누구) / `spec`(어떻게).

### ⚠️ containerPort ≠ Docker의 `-p 8080:80`
- `containerPort: 80`은 **host로 publish하는 게 아님.** Pod 내부 container가 80을 쓴다고 **선언(문서화)**할 뿐.
- cluster 안팎 접근은 **Service/Ingress**가 담당 (→ 6교시).

### Pod 생성 & 확인 (1교시 운영 루프 적용)
```bash
kubectl apply -f .../pod-hello.yaml
kubectl -n week3 get pods -o wide
```
- (실제 출력 → 실습 확인 기록 ①)

### describe로 보는 것 (사건 기록)
| 항목 | 의미 |
|---|---|
| `Node` | 어느 node의 kubelet이 실행 맡았나 |
| `Image` | 어떤 image를 pull/run |
| `Container ID` | runtime이 만든 container 식별자 |
| `Conditions` | Initialized, Ready, ContainersReady, PodScheduled |
| `Events` | scheduling → pulling → created → started 순서 |

- 읽는 포인트(실제 출력 → 실습 확인 기록 ②):
  - **Container ID `containerd://...`** → Day4 3교시 "runtime은 containerd"가 실물로 확인됨.
  - **Host Port: 0/TCP** → containerPort 80은 host에 안 뚫림. 외부 접근은 Service 필요(6교시).
  - **Events 순서** = Scheduled→Pulling→Pulled→Created→Started → Day4 3교시 Pod lifecycle 그대로.
  - 장애 땐 이 Events에서 **어느 단계에서 멈췄는지**가 보임(1교시 "어디서 멈췄나" 원칙).

### logs / exec
```bash
kubectl -n week3 logs hello-pod
kubectl -n week3 exec hello-pod -- curl -sI http://127.0.0.1 || true   # 요청 한번 후 로그 다시
kubectl -n week3 exec hello-pod -- printenv HOSTNAME
kubectl -n week3 exec hello-pod -- nginx -v
```
- ⚠️ nginx image에 `curl`이 **없을 수 있음** → exec 실패 = **Pod 실패 아님**, image에 그 도구가 없다는 뜻. (Week4 debug Pod/ephemeral container로 이어짐)
- ⚠️ **exec로 container 내부를 직접 수정하지 말 것.** manifest와 실제 상태가 어긋나고, Pod 재생성되면 변경 사라짐.
- (실제 출력 → 실습 확인 기록 ③④)

### 직접 만든 Pod의 한계 → 4교시 Deployment로
| 한계 | 설명 |
|---|---|
| replica 관리 없음 | 같은 Pod 여러 개를 선언적으로 유지 어려움 |
| rollout 없음 | image 변경 이력·undo 약함 |
| self-healing 약함 | 삭제된 Pod 다시 만들 controller 없음 |
| Service 연결 약함 | label을 직접 관리해야 함 |

### 한 줄 요약
> **Pod는 단순 container 실행 단위가 아니라, Kubernetes가 스케줄링하고 상태를 추적하는 최소 workload 단위다.**

## 실습 확인 기록

### ① Pod 생성 확인 (get pods -o wide)
```text
$ kubectl -n week3 get pods -o wide
NAME      READY  STATUS   RESTARTS  AGE  IP         NODE
hello-pod 1/1    Running  0         ...  10.244...  paperclip-week3-control-plane
```
- `1/1 Running` = container 1개 중 1개 Ready. IP는 cluster 내부용 Pod IP.

### ② describe pod hello-pod
```text
$ kubectl -n week3 describe pod hello-pod
Node:    paperclip-week3-control-plane/172.18.0.2   ← 이 node의 kubelet이 실행
IP:      10.244.0.5                                 ← Pod IP (cluster 내부용)
Containers:
  nginx:
    Container ID: containerd://5c5c0777...          ← runtime이 containerd임이 보임 (Day4 3교시 연결)
    Image:        nginx:1.27
    Port:         80/TCP        Host Port: 0/TCP     ← Host Port 0 = host로 publish 안 됨 (containerPort≠-p 확인)
    State:        Running       Ready: True
    Restart Count: 0
Conditions:                                          ← 전부 True여야 정상
  PodReadyToStartContainers / Initialized / Ready / ContainersReady / PodScheduled = True
Events:
  Scheduled  → assigned to paperclip-week3-control-plane   (scheduler가 node 결정)
  Pulling    → Pulling image "nginx:1.27"                  (kubelet→runtime image pull)
  Pulled     → Successfully pulled ... in 5.486s
  Created    → Container created
  Started    → Container started
```
- **Container ID `containerd://...`** → Day4 3교시 "runtime은 containerd"가 실물로 확인.
- **Host Port: 0/TCP** → containerPort 80은 host에 안 뚫림. 외부 접근은 Service 필요(6교시).
- **Events 순서** Scheduled→Pulling→Pulled→Created→Started → Pod lifecycle 그대로. 장애 땐 어디서 멈췄는지가 여기 보임.

### ③ exec로 내부 HTTP 요청 (이 nginx:1.27엔 curl 있어 성공)
```text
$ kubectl -n week3 exec hello-pod -- curl -sI http://127.0.0.1
HTTP/1.1 200 OK                ← 200 = Pod 안 nginx가 정상 응답
Server: nginx/1.27.5
Content-Length: 615
```
- `127.0.0.1` = **Pod 내부에서 자기 자신**으로의 요청(localhost). 아직 Service 없이 내부 확인만 한 것.

### ④ logs로 그 요청 흔적 확인
```text
$ kubectl -n week3 logs hello-pod
... nginx/1.27.5 ... start worker process ...           ← 기동 로그(정상 부팅)
127.0.0.1 - - [29/Jun/2026...] "HEAD / HTTP/1.1" 200 0 "-" "curl/7.88.1"   ← 방금 exec curl 요청이 access log에 남음
```
- **기동 로그**(start worker process) = container 정상 부팅.
- 마지막 줄 `"HEAD / HTTP/1.1" 200` = 방금 보낸 `curl -I`(HEAD 요청)가 **access log에 기록** → 요청이 실제 nginx까지 도달했다는 증거.
- 흐름: **exec(요청) → logs(흔적 확인)** 으로 "정말 살아서 응답하나"를 evidence로 남김.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Pod manifest 4대 필드는? | apiVersion(어느 API)·kind(무엇)·metadata(누구)·spec(어떻게) |
| containerPort 의미는? | container가 그 포트 쓴다는 선언(문서화). host publish 아님, 접근은 Service가 |
| describe에서 보는 event 순서는? | scheduling → pulling → created → started |
| exec 실패가 Pod 실패인가? | 아님. image에 그 도구(curl 등)가 없을 뿐 |
| 직접 Pod의 한계는? | replica·rollout·self-healing·Service 연결 약함 → Deployment 필요 |

## notes

### 실습 순서: cluster → namespace → Pod (바깥 그릇부터 안쪽)

```text
1) kind create cluster --config ...   ← cluster(집) 생성        [kind]
        ▼
2) kubectl apply -f namespace.yaml    ← namespace(방) 생성      [kubectl]
        ▼
3) kubectl apply -f hello-pod.yaml    ← Pod(가구) 배치          [kubectl]
```

| 순서 | 명령 | 만드는 것 | 도구 |
|---|---|---|---|
| 1 | `kind create cluster --config ...` | cluster (control plane + node) | **kind** |
| 2 | `kubectl apply -f namespace.yaml` | namespace | kubectl |
| 3 | `kubectl apply -f hello-pod.yaml` | Pod | kubectl |

**왜 이 순서**
- 1 없으면 → cluster 없어서 `localhost:8080 connection refused`.
- 2 없으면 → Pod 넣을 방이 없어 `namespaces "week3" not found`.
- 바깥 그릇부터 안쪽으로: **cluster → namespace → Pod.**

### exec로 응급 수정할 때 (강사님 경험담)
- 긴급 상황엔 `exec`로 들어가 직접 코드를 고치기도 한다 (= 임시 응급처치).
- **그런데 한 번에 여러 개를 고치고 동작 확인을 안 하면** → 뭐가 고친 건지, 어디서 또 깨졌는지 **원인 추적에 시간이 더 걸린다.**
- 원칙: **한 번에 하나씩 바꾸고 → 바로 돌려서 확인 → 다음 것.** (변경 단위를 작게)
- ⚠️ exec 수정은 **manifest엔 안 남으므로**, 응급 처치가 끝나면 **반드시 manifest에도 반영**해야 함. 안 그러면 Pod 재생성 시 변경이 사라지고, "왜 또 똑같은 장애?"가 됨. (2교시 exec 주의와 연결)

**도구 바뀌는 지점 주의**
- **1번만 `kind`** (cluster 자체를 만듦), 2·3번은 `kubectl` (이미 있는 cluster 안에 리소스 넣음).
- 그래서 `kind-config.yaml`은 kubectl로 apply하면 안 됨 → `kind create cluster --config`에 넘기는 파일.

> 한 줄: **kind로 cluster → kubectl로 namespace → kubectl로 Pod. 1번만 kind, 나머지는 kubectl.**

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
