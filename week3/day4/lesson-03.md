# 3교시: Node와 Workload 실행 구조 - kubelet, Runtime, Pod

## 핵심 정리

### Control Plane 이후의 세계 = node에서 실제 실행
- 2교시 control plane은 **결정**까지. 실제 process는 **node**에서 돈다.
  ```text
  API Server에 Pod desired state 저장
    → Scheduler가 node 선택
    → kubelet이 자기 node에 배정된 Pod 확인
    → container runtime이 image pull/create/start
    → kubelet이 Pod status 보고
  ```

### 한 줄 요약
> **Scheduler는 어느 node인지 결정 → kubelet은 그 node에서 Pod를 실제 상태로 맞춤 → container runtime은 container process 실행.**

### Node
- workload가 실제로 실행되는 **machine** (cloud=VM, bare metal=물리서버, **kind=Docker container**).
- 중요 요소: CPU/memory(capacity), disk(image·log), network, **kubelet**(연결 agent), **container runtime**(실제 실행).

### kubelet = node 안의 K8s agent
- 자기 node에 배정된 Pod spec 확인 → runtime 호출(pull/create/start) → **probe 실행**(liveness/readiness/startup) → status 보고 → volume mount 준비.
- **kubelet ≠ scheduler.** node를 고르는 건 scheduler, kubelet은 **배정된 걸 실행 상태로 맞춤**.

### Container Runtime = 실제 container 실행
```text
kubelet → CRI → containerd → runc → container process
```
- ⚠️ Docker 명령 배웠다고 K8s가 Docker daemon으로 실행하는 게 아님. 현대 K8s는 보통 **containerd**.

### Pod = 스케줄링되는 최소 workload 단위
- 포함: container spec, **공유 network namespace(Pod 안 container끼리 localhost 공유)**, volume, labels, restart policy, status.
- 보통 Pod 1개 = container 1개로 시작. **sidecar 패턴**에선 app + log/sidecar container가 한 Pod에 같이.
- **Pod vs container**: Pod = 배포·스케줄 단위 / container = Pod 안에서 도는 process.

### Pod Lifecycle 감각
```text
Pending → image pulling → container creating → Running → Ready
```
| 상태/증상 | 의미 |
|---|---|
| Pending | 스케줄링/리소스/volume 문제 |
| ContainerCreating | image pull·volume mount·runtime 준비 중 |
| ImagePullBackOff | image 이름/tag/registry 인증 문제 |
| CrashLoopBackOff | container가 실행 후 반복 종료 |
| Running but NotReady | process는 떴지만 traffic 받을 준비 안 됨 |

### kind에서 보이는 것
- kind cluster의 **node 자체가 Docker container**.
  ```bash
  docker ps --filter name=paperclip-week3
  kubectl get nodes -o wide
  ```
- `paperclip-week3-control-plane` = K8s node 역할을 하는 container. app Pod는 그 node **안에서** K8s workload로 실행.

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| node 역할은? | workload가 실제 실행되는 machine (CPU/mem/disk/network 제공, kubelet·runtime 탑재) |
| kubelet 역할은? | 자기 node에 배정된 Pod를 실행 상태로 맞춤. runtime 호출·probe·status 보고 |
| container runtime 역할은? | CRI 통해 image pull, container create/start 실제 수행 (보통 containerd) |
| Pod가 container와 다른 점은? | Pod는 스케줄 최소 단위(network/volume 공유), container는 그 안의 process |
| Pod lifecycle 상태는? | Pending → ContainerCreating → Running → Ready (문제 시 ImagePullBackOff/CrashLoopBackOff 등) |
| kind node 확인 명령은? | `docker ps --filter name=paperclip-week3`, `kubectl get nodes -o wide` |

## notes

### 헷갈림 정리: kubectl vs kind vs cluster (셋은 완전히 다른 것)

| 용어 | 정체 | 비유 |
|---|---|---|
| **kubectl** | cluster에 **명령을 보내는 도구(client)** | TV **리모컨** |
| **kind** | 내 PC에 **cluster를 만들어주는 도구** (Kubernetes IN Docker) | TV **설치 기사** |
| **cluster** | 실제로 돌아가는 **K8s 본체** (control plane + node) | TV **본체** |

```text
[kind]   → Docker 위에 cluster를 "생성"
   │
   ▼
[cluster] ← control plane + worker node (실제 K8s가 도는 곳)
   ▲
   │  명령 전송 (API Server로)
[kubectl] → cluster에 "이거 해줘" 요청하는 리모컨
```

- **kind** = cluster를 **만드는** 도구. 한 번 만들면 그 뒤엔 잘 안 씀.
- **kubectl** = 만들어진 cluster를 **조작하는** 도구. `kubectl get pods`, `kubectl apply` 등 매일 씀.
- **cluster** = 둘이 가리키는 **대상(본체)**.
- 핵심: **kubectl은 cluster가 아니라, cluster의 API Server에 요청을 보내는 client.** (2교시 "kubectl은 node에 직접 명령 안 하고 API Server에 요청"과 연결)
- kind든 EKS든 **어떤 cluster든 같은 kubectl로** 조작. kubectl이 **어느 cluster를 가리킬지는 kubeconfig의 context**가 정함.
- 👉 6~8교시(도구 선택 / 설치 / cluster 생성)에서 실제로 손으로 확인하게 됨.

### 헷갈림 정리: "K8s 쓰면 Docker는 안 쓰는 거예요?" → "docker runtime을 쓴다?"

**질문 (수강생)**: Kubernetes 사용 시 Docker는 안 쓰이는 거죠?
**강사님**: docker runtime을 사용한다.

> ⚠️ 아래는 내가 직접 확인·검색한 보강. "Docker"가 여러 의미라 헷갈림.

**"Docker"는 3가지 의미가 있다**

| 의미 | K8s에서 쓰나? |
|---|---|
| ① **Docker 이미지**(이미지 포맷) | ✅ 그대로 씀 (OCI 표준이라 동일) |
| ② **Docker CLI**(`docker build` 등) | ✅ 개발 시 이미지 빌드에 여전히 씀 |
| ③ **Docker를 container runtime으로**(docker daemon이 Pod 직접 실행) | ❌ 현대 K8s는 안 씀 |

**③ runtime이 핵심**
- 현대 K8s는 Pod를 띄울 때 **docker daemon이 아니라 containerd** 사용: `kubelet → CRI → containerd → runc`.
- **K8s 1.24(2022)에서 dockershim 제거** → "K8s가 Docker로 컨테이너를 실행한다"는 더 이상 정확하지 않음.

**그럼 강사님 "docker runtime 사용한다"는?** → kind 맥락이면 절반 맞음.
- **kind는 node 자체를 Docker container로 만든다** (= 여기서 Docker 씀). 하지만 그 node 안에서 Pod를 실행하는 runtime은 **containerd**.
```text
[내 PC]
 └─ Docker          ← kind가 node를 만드는 데 사용 (Docker 씀)
      └─ node (Docker container)
           └─ containerd   ← Pod는 실제로 이게 실행 (runtime)
                └─ Pod
```

**한 줄 결론**
> Docker 이미지는 쓰고, Docker로 빌드도 한다. 하지만 **Pod를 실행하는 runtime은 (현대 K8s에선) docker daemon이 아니라 containerd.** kind에선 Docker가 *node를 만드는 데* 쓰이는 거지 *Pod 실행 runtime*은 아님.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
