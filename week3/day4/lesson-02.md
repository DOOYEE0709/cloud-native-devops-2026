# 2교시: Control Plane 밑바닥 - API Server, etcd, Scheduler, Controller

## 핵심 정리

### Control Plane = cluster의 관리 계층
- 두뇌라기보다 **"상태 저장 + 요청 접수 + 배치 결정 + 조정 loop"** 담당.
- 흐름:
  ```text
  kubectl → API Server → etcd(desired state 저장)
                       → Scheduler(Pod 배치 결정)
                       → Controller(상태 차이 감시)
                       → kubelet(node에서 Pod 실행)
  ```
- 옛날 자료의 **"master node" = 지금의 "control plane node"** (master/slave 표현은 안 씀).

### 5개 핵심 컴포넌트 (한 줄 요약)
> **API Server는 입구, etcd는 기억, Scheduler는 배치, Controller는 조정, kubelet은 node 실행 담당.**

| 컴포넌트 | 위치 | 역할 | container 직접 실행? |
|---|---|---|---|
| **kubectl** | 사용자 PC/CI | API를 호출하는 client | ❌ |
| **API Server** | control plane | 모든 요청의 **입구**, 인증/인가, validation, admission | ❌ |
| **etcd** | control plane | cluster 상태를 저장하는 **key-value store (기억)** | ❌ |
| **Scheduler** | control plane | 미배치 Pod를 **어느 node에 둘지 결정** | ❌ (binding만 기록) |
| **Controller Manager** | control plane | desired ↔ current **차이를 계속 줄임(조정)** | object 생성/수정 |
| **kubelet** | 각 node | 자기 node에 배정된 Pod를 **실제 실행 상태로 맞춤** | runtime에 요청 |
| **Container Runtime** | 각 node | image pull, container create/start **실제 수행** | ✅ |
| **Pod** | 각 node | K8s 배치 최소 단위 (container 1개+ 품음) | — |

### 헷갈리기 쉬운 구분
- **kubectl vs API Server** = client vs server
- **API Server vs etcd** = 요청 입구 vs 상태 저장소
- **Scheduler vs kubelet** = node를 **고름** vs 그 node에서 **실행을 맞춤**
- **Controller vs Scheduler** = 상태 차이 **줄임** vs 미배치 Pod의 node **정함**
- **Pod vs container** = 배포 단위 vs Pod 안에서 도는 process
- **Control Plane vs Worker** = 관리/판단 vs workload 실행

### 핵심: kubectl은 node에 직접 명령하지 않는다
- kubectl은 **오직 API Server에만** 요청. worker node에 직접 접속 X.

### kubectl apply -f pod.yaml 실제 흐름
```text
1. kubectl이 kubeconfig의 current-context 확인
2. API Server에 Pod object 제출
3. API Server가 인증/인가 → validation → admission
4. etcd에 desired state 저장
5. Scheduler가 node 선택(binding 기록)
6. kubelet이 자기 node에 배정된 Pod 확인
7. container runtime이 image pull/create/start
8. kubelet이 Pod status를 API Server에 보고 → etcd 갱신
```
- 포인트: **apply는 container를 바로 실행하는 게 아니라 "API object를 저장"하는 요청.** 실행은 그 뒤 조정 loop가 알아서.

### Scheduler의 판단 재료
- node resource(CPU/mem 여유), node Ready 여부, **taint/toleration**, **affinity**, zone/label/policy.

### 대표 Controller
- Deployment(rollout·ReplicaSet 관리) / ReplicaSet(replica 수 유지) / Node(상태 감시) / Job(batch) / EndpointSlice(Service 뒤 Pod endpoint 갱신).

### Control Plane Node 고르는 기준
- "서비스 트래픽 많이 처리하는 서버"가 아니라 **"cluster 운영을 안정적으로 관리할 서버"**.
- 안정적 CPU/mem, **빠른 disk(etcd 때문)**, 안정적 network, 시간 동기화, 장애 도메인 분산, 접근 통제, app workload 격리.
- 운영은 보통 **3대 이상 홀수**(etcd quorum). managed K8s(EKS 등)는 control plane을 클라우드가 운영.
- **kind 실습**: container 하나가 control plane + worker 역할 겸함(학습 단순화용).

### 장애 시 먼저 의심할 곳
| 증상 | 의심 |
|---|---|
| kubectl 연결 실패 | kubeconfig, context, API Server 접근 |
| object 조회/저장 이상 | API Server, RBAC, admission, etcd |
| Pod 계속 Pending | Scheduler, node resource, taint, volume |
| 배치됐지만 실행 안 됨 | kubelet, runtime, image pull, volume mount |
| replica 수 안 맞음 | Controller Manager, Deployment/ReplicaSet |
| 앱은 떴는데 traffic X | Pod readiness, Service selector, endpoint |

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| API Server 역할은? | 모든 요청의 입구. 인증/인가·validation·admission 후 etcd에 읽기/쓰기 |
| etcd 역할은? | cluster의 desired/current state를 저장하는 key-value store(기억). 백업 중요 |
| Scheduler 역할은? | 미배치 Pod를 어느 node에 둘지 결정해 binding 기록 (실행은 안 함) |
| Controller Manager 역할은? | desired ↔ current 차이를 계속 줄이는 조정 loop |
| kubelet과 control plane의 경계는? | control plane은 node 밖에서 결정/조정, kubelet은 node 안에서 실제 실행을 맞춤 |
| kubectl apply 흐름은? | API Server 제출 → validation/admission → etcd 저장 → Scheduler 배치 → kubelet 실행 → status 보고 |

## notes

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
