# 8교시: 구름 EXP 배움일기

## 실습 확인 기록

① 오늘 evidence 한 번에 수집

```bash
kubectl -n week4-security get sa,role,rolebinding
kubectl auth can-i list pods   --as=system:serviceaccount:week4-security:readonly-viewer -n week4-security
kubectl auth can-i delete pods --as=system:serviceaccount:week4-security:readonly-viewer -n week4-security
kubectl -n kyverno get pods
kubectl get clusterpolicy
kubectl get policyreport -n week4-security
```
```text
# SA: app-runner / default / readonly-viewer / token-demo
# Role: pod-reader / RoleBinding: readonly-viewer-pod-reader → pod-reader
can-i list pods:   yes
can-i delete pods: no
# kyverno: admission/background/cleanup/reports controller Running
# clusterpolicy: disallow-latest-enforce, disallow-privileged-hostpath-enforce, require-owner-label-audit (모두 Ready)
# policyreport: bad-missing-owner FAIL=1
```

② week4-security Pod 현황 — Audit는 통과, Enforce는 거절된 결과

```bash
kubectl -n week4-security get pod
```
```text
bad-missing-owner       Running   # Audit(owner 없음) → 생성됨(위반 기록만)
good-versioned-owner    Running   # 정책 만족 → 통과
security-api-...        Running   # 정상 app Pod
token-mounted-demo      Running   # token mount 데모
# bad-latest / bad-privileged-hostpath 는 Enforce로 거절되어 목록에 없음
```

## 배움일기 표

| 항목 | 기록 |
|---|---|
| 실습 cluster/context | kind-paperclip-w4d2 |
| namespace | `week4-security` |
| 읽기 전용 ServiceAccount | `readonly-viewer` (Role: pod-reader) |
| `can-i list pods` 결과 | `yes` |
| `can-i delete pods` 결과 | `no` |
| forbidden 메시지 핵심 | readonly-viewer cannot delete resource pods in week4-security |
| token mount 확인 결과 | token-demo=token 있음(ca.crt/namespace/token), security-api=없음(automount false) |
| Kyverno Helm release | kyverno 3.8.1 / v1.18.1 (revision 1 deployed, controller Running) |
| Audit policy 결과 | require-owner-label-audit → owner 없는 Pod 생성 허용 + report FAIL 1 |
| Enforce policy 결과 | disallow-latest-enforce / disallow-privileged-hostpath-enforce → 위반 Pod admission denied |
| admission deny 메시지 핵심 | Do not use image tag latest / Privileged·hostPath not allowed |
| 개발팀에 전달할 수정 방향 | latest→버전 tag, privileged·hostPath 제거, owner label 추가 |

## 확인 질문 답변

| 질문 | 내 답 |
|---|---|
| RBAC이 답하는 질문은 | 이 subject가 이 verb를 이 resource에 이 scope에서 할 수 있는가 |
| Kyverno가 답하는 질문은 | 이 object(manifest)가 우리 cluster 기준(정책)을 만족하는가 |
| Role과 ClusterRole의 차이는 | Role=namespace 범위, ClusterRole=cluster 전체/재사용 |
| RoleBinding이 없으면 | Role이 있어도 아무 subject에 권한이 연결되지 않음 → can-i 계속 no |
| `automountServiceAccountToken: false`는 왜 | API 호출이 필요 없는 앱의 token 공격면을 없앰(RCE 시 훔칠 token 없음) |
| Audit와 Enforce의 차이는 | Audit=위반 기록만/생성 허용, Enforce=위반 object admission 거절 |
| `latest` tag를 막는 이유는 | 재현·rollback·audit 어려움. 같은 tag가 다른 image를 가리킬 수 있음 |
| privileged/hostPath가 위험한 이유는 | container isolation 약화, node filesystem 접근 → 사고 범위가 node로 확대 |
| Forbidden과 admission deny 구분은 | Forbidden=authorization(RBAC 권한 없음), admission deny=admission(권한 있으나 정책 위반) |

## notes

### 오늘 배운 내용 요약
| 주제 | 핵심 |
|---|---|
| RBAC | subject, verb, resource, scope |
| ServiceAccount | Pod의 Kubernetes identity |
| token mount | API 접근 필요 여부에 따라 줄이는 공격면 |
| Kyverno | admission 단계에서 manifest 정책 검증 |
| Audit | 위반 기록하되 허용 |
| Enforce | 위반 object 생성 차단 |
| Troubleshooting | Forbidden vs admission deny 구분 |

### final note
```markdown
W4D4에서는 RBAC과 Kyverno를 분리해서 봤다. RBAC은 누가 어떤 API 동작을 할 수 있는지 판단하고,
Kyverno는 권한이 있더라도 배포하려는 object가 정책 기준을 만족하는지 admission 단계에서 검사한다.
readonly ServiceAccount는 list는 가능하지만 delete는 forbidden이었고, Kyverno Enforce 정책은
latest tag와 privileged/hostPath manifest를 admission deny로 차단했다.
```

### 좋은 기록 vs 아쉬운 기록
| 아쉬운 기록 | 좋은 기록 |
|---|---|
| 권한 안 됨 | `readonly-viewer`가 `delete pods` 권한 없음 |
| 정책 때문에 안 됨 | `disallow-latest-enforce`가 `nginx:latest` 차단 |
| Kyverno 설치함 | Helm release, Pod, CRD, webhook 확인 |
| Pod 안 됨 | RBAC인지 admission인지 오류 메시지로 분리 |

### W4D5(GitOps/Argo CD)로 이어지는 질문
| 질문 | W4D5 연결 |
|---|---|
| Git에 policy 위반 manifest가 올라가면 | Argo CD sync 실패 |
| Argo CD가 쓸 SA 권한은 어디까지 | RBAC 최소 권한 |
| GitOps controller가 cluster-admin이면 | 위험 → 최소 권한 |
| policy 때문에 sync가 막히면 누가 고치나 | Git PR + runbook |
| mesh sidecar injection도 policy로 관리 가능한가 | admission + mesh |

### cleanup 결정
W4D5 Argo CD sync-정책 연결을 볼 거면 Kyverno 유지 권장. 리소스가 부족하면 삭제:
```bash
kubectl delete namespace week4-security
helm uninstall kyverno -n kyverno
kubectl delete namespace kyverno
```

### 한 줄 요약
W4D4의 산출물은 보안 이론 암기가 아니라 권한 실패와 정책 실패를 구분하는 운영 evidence다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| evidence 수집 시 `can-i list pods`가 `no`로 나옴(원래 yes) | 쉘에서 `--as=system:serviceaccount:$NS:readonly-viewer`처럼 변수 뒤 `:readonly`가 붙으면 문자열이 깨져(`week4-security`+`eadonly-viewer`) 존재하지 않는 subject 평가 → no. `--as`의 namespace는 리터럴로 쓰면 정상 yes. RBAC 자체는 이상 없음 |
| `helm list -n kyverno`가 STATUS `failed` | revision 2 = "Upgrade failed: context canceled"(설치 중 취소). 실제 Kyverno는 revision 1로 Running 정상. 재설치 불필요. 깔끔히 하려면 `helm rollback kyverno 1 -n kyverno` 가능 |
