# 1교시: Day4 요약 + GitOps 개념

```bash
# 실습 환경 변수
export ARGONS=argocd
export NS=week4-gitops
export REPO=https://github.com/niceguy61/kdt_devops_lecture_2026_rev2.git
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① `kubectl config current-context` | `kind-paperclip-w4d2` (오늘 실습 대상 클러스터) |
| ② `kubectl get nodes` | `paperclip-w4d2-control-plane   Ready   control-plane   v1.36.1` |
| ③ `kubectl get ns kyverno` | `kyverno   Active` — W4D4 policy가 아직 살아있음 → GitOps sync의 admission gate |
| ④ `kubectl get ns argocd` | `NotFound` — 아직 GitOps controller 없음(2교시에서 설치) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| GitHub Actions와 Argo CD 역할 차이는? | Actions=CI(build/test/push, 기준=workflow run), Argo CD=CD(deploy/sync, 기준=Git desired state) |
| GitOps에서 "기준"은 어디인가? | 사람의 터미널(kubectl apply)이 아니라 Git repository의 manifest |
| drift란? | Git 선언 상태와 cluster 실제 object가 달라진 상태 (예: Git replicas 1, Cluster 2 → OutOfSync) |
| Argo CD가 다른 namespace에 배포하는 근거는? | namespace 벽을 넘는 게 아니라 controller SA 토큰으로 API server 호출 → RBAC 허용 |
| W4D4 Kyverno와 GitOps 연결은? | sync manifest가 policy 위반이면 admission deny → Argo CD가 sync 실패로 표시 |

## notes

### CI와 CD는 책임이 다르다
W3D3의 GitHub Actions는 CI gate, W4D5의 Argo CD는 CD/GitOps다.

```text
CI:  source → test → SAST/DAST → docker build → Docker Hub push
CD:  Git manifest → Argo CD → Kubernetes API → cluster state
```

| 구분 | GitHub Actions | Argo CD |
|---|---|---|
| 주 역할 | build/test/push | deploy/sync |
| 기준 | workflow run | Git desired state |
| 산출물 | image, log, artifact | Application sync status |
| 실패 위치 | test/build/push step | sync/diff/health |
| secret | registry token | repo credential, cluster access |

"Actions가 있으면 Argo CD 필요 없다"는 오해. CI와 CD 책임이 다르고, Argo CD는 보통 image를 build하지 않는다.

### GitOps = 기준을 Git으로 고정
GitOps는 Git을 운영 상태의 기준으로 삼는다. cluster에서 직접 수정한 값이 Git과 다르면 drift다.

```text
Git: replicas 1
Cluster: replicas 2
Argo CD: OutOfSync
```

핵심 질문은 "누가 cluster를 바꿨나"보다 "Git 기준과 cluster 기준이 왜 달라졌나"다. GitOps는 마법 자동 배포가 아니라 **변경의 기준을 사람 터미널에서 Git으로 옮기는 운영 방식**.

### desired state / current state 계층
| 계층 | 비교 대상 |
|---|---|
| Kubernetes controller | object spec vs 실제 Pod 상태 |
| Argo CD | Git manifest vs cluster object |
| 운영자 | 기대 사용자 상태 vs 실제 사용자 경험 |

이 계층을 섞으면 문제 분석이 느려진다.

### namespace 간 통신 vs API 권한
Argo CD는 `argocd` namespace에 있지만 `week4-gitops`에 Deployment를 만든다. 벽을 몰래 넘는 게 아니라 controller SA 토큰으로 API server에 요청하고 RBAC이 허용한 것.

```text
argocd-application-controller Pod
  → ServiceAccount token
  → https://kubernetes.default.svc
  → API server RBAC check
  → week4-gitops namespace resources
```

| 질문 | 확인할 것 |
|---|---|
| HTTP 호출이 되는가 | Service DNS, port, endpoint, NetworkPolicy |
| 리소스 조회/생성이 되는가 | ServiceAccount, Role/ClusterRole, Binding |
| metric이 보이는가 | scraper 권한, ServiceMonitor, metrics API |
| admission이 막는가 | webhook, policy, namespace selector |

"다른 namespace와 통신된다"는 말은 이렇게 상황별로 나눠야 한다.

### GitOps와 Kyverno(W4D4 연결)
```text
Git manifest → Argo CD sync → Kubernetes API → Kyverno admission → allow/deny
```
Kyverno가 deny하면 Argo CD는 sync 실패를 보여준다. 이때 Argo CD 문제가 아니라 policy violation일 수 있다. 보안 정책은 GitOps와 충돌이 아니라 배포 품질을 높이는 gate.

### 자주 하는 오해
| 오해 | 정리 |
|---|---|
| Actions가 있으면 Argo CD 불필요 | CI와 CD 책임이 다름 |
| Argo CD가 image를 build한다 | image build는 보통 CI |
| sync 성공이면 서비스 정상 | health와 user traffic 확인 필요 |
| mesh 쓰면 앱 문제가 사라진다 | traffic 관찰/제어 계층일 뿐 |

### 한 줄 요약
GitOps는 Kubernetes 배포의 기준을 사람의 터미널이 아니라 **Git repository**로 옮기는 운영 방식이다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
