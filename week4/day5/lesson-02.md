# 2교시: Argo CD Helm 설치

```bash
# 실습 환경 변수
export ARGONS=argocd
export NS=week4-gitops
export LAB=cloud-native-devops-2026/week4/day5/labs
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① `helm repo add argo https://argoproj.github.io/argo-helm` | `"argo" has been added to your repositories` |
| ② `helm repo update argo` | `Update Complete. Happy Helming!` |
| ③ `helm upgrade --install argocd argo/argo-cd --namespace $ARGONS --create-namespace -f $LAB/argocd/values.yaml` | `Install complete`, REVISION 1 |
| ④ `helm list -n $ARGONS` | `argocd  deployed  argo-cd-10.1.2  v3.4.4` |
| ⑤ `kubectl -n $ARGONS wait --for=condition=Ready pod --all --timeout=240s` | server/controller/repo-server/redis/appset 순차 Ready (redis-secret-init은 Job이라 무시) |
| ⑥ `kubectl -n $ARGONS get pods` | `application-controller-0`, `applicationset-controller`, `redis`, `repo-server`, `server` 모두 `1/1 Running` |
| ⑦ `kubectl -n $ARGONS get svc` | `argocd-server  ClusterIP  80/TCP,443/TCP` (kind라 LoadBalancer 대신 ClusterIP) |
| ⑧ `kubectl -n $ARGONS get sa` | `argocd-application-controller`, `argocd-server`, `argocd-repo-server` SA 존재 |
| ⑨ `kubectl get clusterrolebinding \| grep argocd` | `argocd-application-controller`, `argocd-server` 바인딩 확인 |
| ⑩ `kubectl auth can-i create deployments --as=system:serviceaccount:argocd:argocd-application-controller -n $NS` | `yes` — controller가 target namespace에 배포 권한 있음 |
| ⑪ `kubectl -n $ARGONS get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d; echo` | `DFBvheEEqok4SkxF` (초기 admin password, 공유 금지) |
| ⑫ UI 접속용 `kubectl -n $ARGONS port-forward svc/argocd-server 18080:80` | `http://localhost:18080`, user `admin` |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Argo CD 핵심 구성요소 3개 역할은? | server=UI/API, application-controller=sync/health 판단, repo-server=Git/Helm/Kustomize manifest 렌더링 |
| kind에서 왜 ClusterIP + port-forward? | LoadBalancer external IP가 없으니 로컬은 port-forward로 접속 |
| `can-i ... yes`의 의미는? | controller SA가 week4-gitops에 Deployment 생성 권한 보유 → sync 가능. `no`면 sync 실패 |
| values.yaml에서 dex/applicationSet를 끈 이유는? | 수업은 GitOps 개념 확인 목적이라 SSO/notification/appset은 축소 |
| 설치 검증은 UI가 뜨면 끝인가? | 아니오. controller/repo-server/Application sync 준비 상태까지 확인해야 함 |

## notes

### Argo CD 구성요소
| 구성요소 | 역할 |
|---|---|
| argocd-server | UI/API endpoint |
| application-controller | Application sync와 health 판단 |
| repo-server | Git/Helm/Kustomize manifest 렌더링 |
| redis | cache/session 보조 |
| dex | SSO/OIDC 연동 (수업에서는 비활성) |

수업은 GitOps 개념 확인이 목표라 dex/notification/applicationSet를 줄인다.

### values.yaml 핵심
```yaml
server:
  service:
    type: ClusterIP     # kind라 LoadBalancer 대신 port-forward
configs:
  params:
    server.insecure: true
dex:
  enabled: false
applicationSet:
  enabled: false
notifications:
  enabled: false
```

### 다른 namespace에 배포하는 원리
Argo CD는 `argocd`에 설치되지만 destination은 `week4-gitops` 등 다른 namespace가 될 수 있다. 통신을 두 층으로 나눠 본다.

| 층 | 의미 | 확인 |
|---|---|---|
| API server 통신 | controller가 `https://kubernetes.default.svc`로 API 호출 | Pod env, Service DNS |
| 권한 | controller SA가 target namespace에 create/update 가능 | RBAC, `kubectl auth can-i` |

Argo CD가 모든 namespace를 보는 것처럼 보이는 이유 = chart가 **SA + ClusterRole + Binding**을 함께 설치하기 때문. 운영에서는 Project/RBAC으로 제한해야 한다. `can-i ... yes`면 sync 가능, `no`면 sync 실패.

### admin password 다루기
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```
| 항목 | 설명 |
|---|---|
| 수업용 | 초기 password로 UI 접속 |
| 운영 | SSO/OIDC, rotation, RBAC 필요. 초기 secret은 로그인 후 삭제 권장 |
| 공유 금지 | 화면 공유 시 노출 주의 |

### Pod가 안 뜰 때
| 증상 | 원인 후보 |
|---|---|
| Pending | local resource 부족 |
| ImagePullBackOff | registry/network |
| CrashLoopBackOff | values/secret/config |
| UI 접속 실패 | port-forward 대상/port 오류 |

`argocd-redis-secret-init`은 1회성 Job이라 `wait --all`에서 timeout으로 보여도 정상. 실제 Deployment/StatefulSet Pod가 Running이면 OK.

### 한 줄 요약
Argo CD 설치 검증은 UI가 뜨는 것에서 끝나지 않고 **controller·repo-server·Application sync 준비 상태**까지 확인해야 한다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| `wait --for=condition=Ready pod --all`이 redis-secret-init/일부에서 timeout | 1회성 Job Pod라 Ready condition 안 붙음 → `get pods`로 실제 workload가 `1/1 Running`인지 확인하면 정상 |

