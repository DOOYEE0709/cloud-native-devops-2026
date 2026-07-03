# 1교시: Day3 요약 + Kubernetes 권한 모델

## 실습 확인 기록

```bash
export NS=week4-security
export LAB=week4/day4/labs
```

① 오늘 실습용 namespace 생성

```bash
kubectl apply -f $LAB/rbac/namespace.yaml
```
```text
namespace/week4-security created
```

② RoleBinding 만들기 전 — readonly-viewer는 pods list 권한 없음 (RBAC deny-by-default)

```bash
kubectl auth can-i list pods --as=system:serviceaccount:$NS:readonly-viewer -n $NS
```
```text
no
```

③ Role + RoleBinding 적용

```bash
kubectl apply -f $LAB/rbac/readonly-role.yaml
```
```text
role.rbac.authorization.k8s.io/pod-reader created
rolebinding.rbac.authorization.k8s.io/readonly-viewer-pod-reader created
```

④ RoleBinding 연결 후 — 같은 질문이 no → yes 로 바뀜

```bash
kubectl auth can-i list pods --as=system:serviceaccount:$NS:readonly-viewer -n $NS
```
```text
yes
```

⑤ 최소 권한 확인 — 같은 subject라도 delete는 막힘 (Role에 delete 미포함)

```bash
kubectl auth can-i delete pods --as=system:serviceaccount:$NS:readonly-viewer -n $NS
```
```text
no
```

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| ②에서 no가 나온 이유는 | Role/RoleBinding이 없어 subject에 아무 권한도 부여되지 않았고, RBAC은 기본이 전부 거부(deny-by-default)이기 때문 |
| ④에서 yes로 바뀐 이유는 | RoleBinding이 readonly-viewer(subject)와 pod-reader(Role)를 연결해, Role의 pods get/list/watch 권한이 subject에게 적용됨 |
| Role만 apply하면 권한이 생기는가 | 아니다. Role은 권한 묶음일 뿐이고, RoleBinding으로 subject와 연결돼야 실제 권한이 생긴다 |
| Forbidden과 admission deny의 차이는 | Forbidden은 authorization(RBAC) 단계에서 권한이 없어 막힌 것, admission deny는 권한은 있으나 object 내용이 정책(Kyverno 등)을 위반해 막힌 것 |

## notes

### 왜 observability(W4D3) → security(W4D4)인가
관찰은 문제를 *발견*하게 해주고, 권한과 정책은 문제가 *반복되는 경로*를 줄인다.

| W4D3 질문(관찰) | W4D4 질문(권한/정책) |
|---|---|
| 어떤 Pod가 restart했는가 | 누가 그 Pod를 수정할 수 있는가 |
| 어떤 target이 DOWN인가 | 누가 monitoring 설정을 바꿀 수 있는가 |
| 어떤 alert가 firing인가 | 누가 alert rule을 만들 수 있는가 |
| readiness가 왜 실패했는가 | readiness 없는 Pod를 배포 전에 막을 수 있는가 |
| latest tag가 어떤 문제를 만들었는가 | latest tag 사용을 admission에서 차단할 수 있는가 |

### Kubernetes API 요청 흐름
```text
client(kubectl, controller, CI)
  -> authentication      (누구인가)
  -> authorization(RBAC) (권한이 있는가)
  -> admission(policy/webhook) (object 내용이 규칙에 맞는가)
  -> etcd 저장
```

| 단계 | 실패 예시 | 의미 |
|---|---|---|
| authentication | 인증 정보 없음 | 누구인지 모름 |
| authorization | `Forbidden` | 누구인지는 알지만 권한 없음 |
| admission | `admission webhook denied` | 권한은 있지만 object 내용이 정책 위반 |
| persistence | API validation error | object schema 또는 필드 오류 |

### RBAC의 네 가지 질문
| 질문 | 예시 |
|---|---|
| 누가 | `system:serviceaccount:week4-security:readonly-viewer` |
| 무엇에 | `pods`, `deployments`, `services` |
| 어떤 동작을 | `get`, `list`, `watch`, `create`, `delete` |
| 어느 범위에서 | `week4-security` namespace |

네 가지 중 하나라도 빠지면 권한 설명이 흐려진다.

### Subject (user / group / ServiceAccount)
| Subject | 주로 쓰는 곳 |
|---|---|
| User | 사람이 kubeconfig로 접근 |
| Group | 조직/팀 단위 권한 |
| ServiceAccount | Pod 안에서 실행되는 application/controller |

Kubernetes 안에서 도는 workload는 대부분 ServiceAccount identity로 API를 호출 → 오늘은 ServiceAccount 중심.

### Role과 ClusterRole
| 구분 | 범위 | 예시 |
|---|---|---|
| Role | namespace 안 | `week4-security`에서 Pod 읽기 |
| ClusterRole | cluster 전체 또는 재사용 | Node 보기, CRD 보기, 여러 namespace 공통 권한 |

ClusterRoleBinding을 처음부터 남발하면 권한 범위가 커진다 → namespace Role + RoleBinding으로 최소 권한을 먼저 만든다.

### RoleBinding — subject와 Role을 연결
```text
ServiceAccount readonly-viewer
  -> RoleBinding readonly-viewer-pod-reader
  -> Role pod-reader
  -> pods/services/deployments get/list/watch
```
Role만 만들어서는 아무도 권한을 갖지 않는다. RoleBinding이 있어야 subject가 권한을 얻는다.

### 권한(RBAC)과 정책(Kyverno)을 섞지 않기
RBAC은 "할 수 있는가", Kyverno는 "이 manifest가 허용되는가"를 본다.

| 오류 | 원인 후보 |
|---|---|
| `User ... cannot delete resource pods` | RBAC |
| `admission webhook ... denied the request` | Kyverno/admission |
| `unknown field` | YAML schema |
| `ImagePullBackOff` | image/registry/runtime |

### 오늘의 security mental model
```text
RBAC:     "이 사람이/앱이 이 API를 호출할 수 있는가"
Kyverno:  "이 object가 우리 cluster 기준을 만족하는가"
Evidence: "어디서 거절됐는가"
```

### 한 줄 요약
Kubernetes 보안 troubleshooting은 **RBAC에서 막혔는지, admission policy에서 막혔는지를 분리**하는 것에서 시작한다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| Docker daemon connection refused / kubectl connection refused | Docker Desktop이 꺼져 있었음 → 재실행, kind 노드 컨테이너 `docker start` 후 복구 |
| `the path "week4/day4/labs/labs/rbac/namespace.yaml" does not exist` | `$LAB`이 이미 `week4/day4/labs`까지 포함 → `$LAB/labs/...`로 labs가 중복. `$LAB/rbac/...` 또는 절대경로로 해결 |
