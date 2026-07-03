# 2교시: RBAC 최소 권한 실습

## 실습 확인 기록

```bash
export NS=week4-security
export LAB=week4/day4/labs
```

① 나머지 RBAC 리소스 적용 (namespace / readonly-role은 1교시에서 이미 적용, 멱등이라 재실행 무방)

```bash
kubectl apply -f $LAB/rbac/serviceaccounts.yaml
kubectl apply -f $LAB/rbac/sample-workload.yaml
```
```text
serviceaccount/readonly-viewer created
serviceaccount/app-runner created
serviceaccount/token-demo created
deployment.apps/security-api created
service/security-api created
```
(unchanged는 이미 존재해서 변화 없음 = 적용된 상태. created와 동일하게 취급)

② 생성된 리소스 확인

```bash
kubectl -n week4-security get sa
kubectl -n week4-security get role,rolebinding
kubectl -n week4-security get deploy,svc,pod
```
```text
NAME              AGE
app-runner        30m
default           43m
readonly-viewer   30m
token-demo        30m

NAME                                        CREATED AT
role.rbac.authorization.k8s.io/pod-reader   2026-07-03T00:59:05Z

NAME                                                               ROLE            AGE
rolebinding.../readonly-viewer-pod-reader                          Role/pod-reader 30m

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/security-api   1/1     1            1           7m20s

NAME                   TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/security-api   ClusterIP   10.96.191.0   <none>        80/TCP    7m20s

NAME                                READY   STATUS    RESTARTS   AGE
pod/security-api-5fbdf88df7-8bchv   1/1     Running   0          7m20s
```

③ Role 내용 확인 — get/list/watch만 있고 delete/create/update 없음

```bash
kubectl -n week4-security get role pod-reader -o yaml
```
```text
rules:
- apiGroups: [""]
  resources: [pods, services, endpoints, configmaps]
  verbs: [get, list, watch]
- apiGroups: ["apps"]
  resources: [deployments, replicasets]
  verbs: [get, list, watch]
```
verbs가 get/list/watch뿐 → delete/create/update 없음. core group(pods 등)과 apps group(deployments 등) 둘 다 읽기만 허용.

④ can-i 읽기 vs 삭제 (no는 exit code 실패이므로 `|| true`로 스크립트 중단 방지)

```bash
kubectl auth can-i list pods --as=system:serviceaccount:week4-security:readonly-viewer -n week4-security
kubectl auth can-i delete pods --as=system:serviceaccount:week4-security:readonly-viewer -n week4-security || true
```
```text
yes
no
```
list=yes(Role에 있음), delete=no(Role에 없음). can-i는 실제 삭제를 하지 않고 권한만 물어본다.

⑤ 실제 Forbidden 만들기 — readonly-viewer로 Pod 삭제 시도

```bash
kubectl --as=system:serviceaccount:week4-security:readonly-viewer -n week4-security delete pod -l app=security-api
```
```text
Error from server (Forbidden): pods "security-api-5fbdf88df7-8bchv" is forbidden:
User "system:serviceaccount:week4-security:readonly-viewer"
cannot delete resource "pods" in API group "" in the namespace "week4-security"
```
can-i가 예측한 no가 실제 삭제 시도에서 Forbidden으로 확인됨. 메시지에서 User / cannot delete / resource pods / namespace 4조각을 읽는다.

⑥ namespace scope 확인 — RoleBinding이 week4-security에만 있어 default에선 no

```bash
kubectl auth can-i list pods --as=system:serviceaccount:week4-security:readonly-viewer -n default
```
```text
no
```
week4-security에선 list=yes였지만 default에선 no. RoleBinding이 week4-security에만 있어 scope 밖은 권한 없음.

⑦ RoleBinding 연결 확인 — subjects와 roleRef가 맞아야 권한 연결

```bash
kubectl -n week4-security get rolebinding readonly-viewer-pod-reader -o yaml
```
```text
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
subjects:
- kind: ServiceAccount
  name: readonly-viewer
  namespace: week4-security
```
subjects(readonly-viewer SA) ↔ roleRef(pod-reader Role) 연결이 성립해야 권한이 붙는다. 이 연결이 없으면 can-i는 계속 no.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| readonly-viewer는 왜 list는 되고 delete는 안 되는가 | Role(pod-reader)의 verbs에 get/list/watch만 있고 delete가 없어서 |
| Forbidden 메시지에서 읽어야 할 4가지는 | User(누가) / cannot delete(어떤 verb) / resource pods(무엇에) / namespace week4-security(어느 범위) |
| default namespace에서 no가 나오는 이유는 | RoleBinding이 week4-security namespace에만 존재해 다른 namespace엔 권한이 연결되지 않음 |
| can-i가 no일 때 스크립트에서 주의할 점은 | 사람 눈엔 no만 보이지만 shell exit code는 실패 → `set -e` 환경에서 멈출 수 있어 `|| true` 필요 |

## notes

### 왜 최소 권한(least privilege)인가
편하다고 넓은 권한을 주면 사고 범위가 커진다.

| 넓은 권한 | 위험 |
|---|---|
| 모든 namespace pod delete 가능 | 다른 팀 서비스까지 삭제 가능 |
| secret list 가능 | 민감정보 노출 |
| cluster-admin 공유 | 감사/audit 불가능 |
| default ServiceAccount에 권한 부여 | 어떤 Pod가 권한을 쓰는지 추적 어려움 |

### 이 실습의 ServiceAccount
| ServiceAccount | 용도 |
|---|---|
| `readonly-viewer` | RBAC can-i 실습 (읽기 전용) |
| `app-runner` | application Pod 실행 |
| `token-demo` | token mount 확인 |
| `default` | 쓰지 않는 것이 목표 |

### Role의 핵심 (pod-reader)
```yaml
resources: ["pods", "services", "endpoints", "configmaps"]
verbs: ["get", "list", "watch"]
```
delete/create/update가 없다 → 읽기는 되지만 삭제는 안 된다.

### Forbidden 메시지 읽는 법
```text
Error from server (Forbidden): pods "..." is forbidden:
User "system:serviceaccount:week4-security:readonly-viewer"
cannot delete resource "pods" in API group "" in the namespace "week4-security"
```
| 부분 | 의미 |
|---|---|
| User | 어떤 subject로 요청했는가 |
| cannot delete | 어떤 verb가 막혔는가 |
| resource pods | 어떤 resource가 막혔는가 |
| namespace week4-security | 어떤 scope인가 |

### RoleBinding 연결 구조
```yaml
subjects:
  - kind: ServiceAccount
    name: readonly-viewer
roleRef:
  kind: Role
  name: pod-reader
```
subject와 roleRef가 맞아야 권한이 연결된다.

### 자주 하는 실수
| 실수 | 증상 |
|---|---|
| Role만 만들고 RoleBinding 없음 | can-i가 계속 no |
| ServiceAccount namespace 오타 | subject가 다른 identity로 잡힘 |
| RoleBinding namespace 착각 | 다른 namespace에서 권한 없음 |
| resource 이름 오타 | 권한이 있어 보이지만 적용 안 됨 |
| ClusterRoleBinding 남발 | 필요 이상 권한 부여 |

### 최소 권한 정리표
| 운영 요청 | 권한 방향 |
|---|---|
| 앱 로그 보기 | pods/log get |
| 배포 상태 보기 | deployments get/list/watch |
| Pod 삭제 | 운영자에게만 제한 |
| Secret 조회 | 극히 제한 |
| 모든 namespace 접근 | cluster 운영자에게만 제한 |

### 한 줄 요약
RBAC은 권한을 추측하는 게 아니라 **can-i와 forbidden 메시지로 subject·verb·resource·scope를 확인**하는 작업이다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
