# Week 3 Day 4 — Kubernetes 개념과 kind 로컬 cluster 구축

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Kubernetes 탄생 배경과 Cluster 운영 문제 | container는 실행 표준, K8s는 운영 표준 API. desired state 발상. Swarm보다 K8s가 사실상 표준. ECS/EKS/Beanstalk·Ingress, ALB vs K8s |
| 2교시 | Control Plane 밑바닥 | API Server(입구)·etcd(기억)·Scheduler(배치)·Controller(조정)·kubelet(node 실행). kubectl은 node가 아니라 API Server에 요청. `apply`=object 저장 |
| 3교시 | Node와 Workload 실행 구조 | kubelet→CRI→containerd→runc. Pod=최소 스케줄 단위. runtime은 Docker daemon이 아니라 containerd. kubectl/kind/cluster 구분 |
| 4교시 | 선언적 API와 Reconciliation | desired/current/reconcile. self-healing·rollout·scaling이 같은 구조. replica 개념. controller loop |
| 5교시 | 장점·단점·많이 쓰이는 분야 | 장단점은 control plane+reconciliation에서 나옴. managed K8s(EKS/AKS/GKE). stateful(DB)은 K8s에 잘 안 올림. observability·Argo CD·비용 |
| 6교시 | 실습 도구 선택 - kind 기준 | kind=Kubernetes IN Docker. 환경 섞여도 표준화 쉬움. node가 container라 production용 아님. single control plane |
| 7교시 | WSL/macOS kubectl, kind 설치 | Docker(기반)·kubectl(CLI)·kind(cluster 생성). OS별 설치, 설치 검증, 실패 대응 |
| 8교시 | kind Cluster 생성과 확인 | `kind create cluster`, context 확인, node Ready, namespace, k9s. 삭제는 통째로 날아감(주의). deprecation·버전 업그레이드 |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 핵심 정리·실습 확인 기록·확인 질문·notes·Blocker Log |
| `labs/kind-cluster/` | kind cluster 설정(`kind-config.yaml`) |
| `labs/k8s-first-pod/` | 첫 Pod·namespace 실습 자료 |
| `assets/` | 교시별 강의 이미지 및 실습 확인 스크린샷 |

## 핵심 한 줄
Kubernetes는 container를 많이 실행하는 명령 묶음이 아니라, 원하는 상태를 API object로 선언하면 control plane과 node가 그 상태에 가까워지도록 조정하는 platform이다. desired/current/reconcile 구조와 control plane 구성요소(API Server·etcd·Scheduler·Controller·kubelet)를 설명하고, kind로 local cluster를 만들어 context·node를 확인할 수 있으면 Day4 완료.

## 다음 연결
Day5에서 이 kind cluster 위에 첫 Pod → Deployment → Service를 직접 올리며, kubectl 운영 루프(apply·get·describe·logs·exec)로 상태를 evidence로 읽는다.
