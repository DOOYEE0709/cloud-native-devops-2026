# Week 4 Day 4 — Kubernetes Security: RBAC과 Kyverno로 권한·정책을 분리하기

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Day3 요약 + Kubernetes 권한 모델 | API 흐름 authn→authz(RBAC)→admission→etcd. RBAC 네 질문(누가/무엇에/동작/범위). Role만으론 권한 없고 RoleBinding이 연결. no→yes를 can-i로 확인 |
| 2교시 | RBAC 최소 권한 실습 | readonly-viewer: list=yes / delete=no. 실제 삭제 시도 → `Forbidden`(authorization). 다른 ns=no로 scope 증명. subject↔roleRef 연결 확인 |
| 3교시 | app Pod와 ServiceAccount | SA=Pod의 identity. `automountServiceAccountToken: false`면 token 없음(No such file=의도된 보안). token=Projected Volume(만료·rotation). RCE+token mount 시 RBAC 권한만큼 피해 → 둘 다 좁힘 |
| 4교시 | Kyverno·ESO 설치/Preview | Kyverno=admission, ESO=reconciliation. Helm 설치 후 controller/CRD/webhook 4종 건강 확인 후 정책. `repo add≠install`, chart=무엇/values=어떻게, CRD는 chart 소속. ESO는 개념 preview만 |
| 5교시 | Kyverno Policy 1 (latest·label) | Audit=기록만/생성 허용, Enforce=admission 거절. owner 없는 Pod는 Audit로 생성+report FAIL. `nginx:latest`는 Enforce로 `admission denied`. 정책 넣으니 resource webhook 0→활성화 |
| 6교시 | Kyverno Policy 2 (privileged·hostPath) | 정책 하나에 rule 2개. privileged/hostPath Pod 거절, 위반 필드 경로까지 보고. anchor `=(volumes)`(있을 때만 검사)/`X(hostPath)`(있으면 실패)로 정상 Pod 오차단 방지 |
| 7교시 | 권한/정책 장애 분석 | 두 갈래: 권한 없음→RBAC Forbidden(Role/RoleBinding), 정책 위반→admission deny(policy/manifest). 증상별 첫 확인 명령. 개발팀엔 policy·rule·message·수정 field 전달 |
| 8교시 | 구름 EXP 배움일기 | evidence 수집·배움일기·회고. list=yes/delete=no, 정책 3개 Ready, Audit 통과 vs Enforce 거절. W4D5 GitOps로 이어지는 보안 질문 |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 실습 확인 기록·확인 질문·notes·Blocker Log |
| `labs/rbac/` | namespace, ServiceAccount, Role/RoleBinding, 샘플 workload, token mount 데모 |
| `labs/kyverno/values.yaml` | Kyverno Helm values (controller 각 1 replica, admission/aggregate report) |
| `labs/kyverno/*enforce*.yaml`, `*audit*.yaml` | 수업용 Kyverno 정책 |
| `labs/kyverno/bad-*.yaml` / `good-pod.yaml` | 정책 위반 / 통과 manifest |

### labs/rbac 구성

| 파일 | 역할 |
|---|---|
| `namespace.yaml` | `week4-security` 격리 namespace |
| `serviceaccounts.yaml` | readonly-viewer / app-runner / token-demo (default 회피) |
| `readonly-role.yaml` | Role `pod-reader`(get/list/watch) + RoleBinding |
| `sample-workload.yaml` | `security-api` Deployment/Service (`app-runner` SA, token automount false) |
| `token-mounted-pod.yaml` | `token-mounted-demo` (token mount 켠 대조군) |

### labs/kyverno 정책 구성

| 파일 | 모드 | 막는 것 |
|---|---|---|
| `require-owner-label-audit.yaml` | Audit | owner label 누락(기록만) |
| `disallow-latest-enforce.yaml` | Enforce | `image: *:latest` |
| `disallow-privileged-hostpath-enforce.yaml` | Enforce | `privileged: true`, `hostPath` |
| `bad-pod-missing-owner.yaml` | — | owner 없음(Audit 대상, 생성됨) |
| `bad-pod-latest.yaml` | — | latest tag(Enforce로 거절) |
| `bad-pod-privileged-hostpath.yaml` | — | privileged+hostPath(Enforce로 거절) |
| `good-pod.yaml` | — | 모든 정책 통과(Running) |

## 실습 환경

kind cluster `paperclip-w4d2`(node `paperclip-w4d2-control-plane`, v1.36.1), W4D2~D3에 이어서 진행. helm v4.2.2.

- **week4-security** namespace: RBAC 실습 + Kyverno 정책 대상 workload.
- **kyverno** namespace: Kyverno chart `3.8.1` / app `v1.18.1` (admission/background/cleanup/reports controller). CRD 19종, validating/mutating webhook.
- 권한 확인은 impersonation으로:
  ```bash
  kubectl auth can-i list pods   --as=system:serviceaccount:week4-security:readonly-viewer -n week4-security   # yes
  kubectl auth can-i delete pods --as=system:serviceaccount:week4-security:readonly-viewer -n week4-security   # no
  ```
- ⚠️ `--as` 문자열에 namespace를 변수로 넣으면(`...:$NS:readonly...`) 일부 쉘에서 `:r`이 깨져 잘못된 subject가 평가돼 `no`가 나올 수 있다. `--as`의 subject는 리터럴로 쓴다. RBAC 자체 문제와 혼동 금지.

## Verified Baseline

```text
kind cluster Ready (paperclip-w4d2)
can-i list pods (readonly-viewer)   = yes
can-i delete pods (readonly-viewer) = no  → 실제 삭제 시 Forbidden
security-api Pod: token directory 없음 (automountServiceAccountToken: false)
Kyverno admission/background/cleanup/reports controller Running
clusterpolicy 3종 Ready (require-owner-label-audit / disallow-latest-enforce / disallow-privileged-hostpath-enforce)
bad-latest Pod             → admission denied
bad-privileged-hostpath   → admission denied (rule 2개)
bad-missing-owner         → Running (Audit) + policyreport FAIL 1
good-versioned-owner      → Running
```

## 핵심 한 줄

Kubernetes 보안 troubleshooting은 **RBAC에서 막혔는지(Forbidden), admission 정책에서 막혔는지(admission denied)를 분리**하는 것에서 시작한다. RBAC은 "누가 이 API를 호출할 수 있나"(authorization), Kyverno는 "이 object가 우리 기준을 만족하나"(admission)를 본다. 같은 "막힘"이라도 봐야 할 곳(Role/RoleBinding vs policy/manifest)이 다르고, 정책은 Audit로 먼저 관찰한 뒤 Enforce로 좁혀야 정상 배포까지 막지 않는다.

## 다음 연결 (W4D5 GitOps/Argo CD)

오늘 세운 RBAC·Kyverno는 GitOps로 바로 이어진다. "Git에 policy 위반 manifest가 올라가면?"(Argo CD sync 실패), "Argo CD가 쓸 ServiceAccount 권한은 어디까지?"(RBAC 최소 권한), "GitOps controller가 cluster-admin이면?"(위험), "policy 때문에 sync가 막히면 누가 고치나?"(Git PR + runbook)가 다음 질문이다.

## cleanup

W4D5에서 Argo CD sync↔정책 연결을 볼 거면 **Kyverno 유지 권장**. 리소스가 부족하면 삭제:
```bash
kubectl delete namespace week4-security
helm uninstall kyverno -n kyverno
kubectl delete namespace kyverno
```
유지 시 `helm list -A`와 `kubectl get clusterpolicy`, `kubectl get ns` 결과를 기록한다.

## Official References

| Topic | Reference |
|---|---|
| Kubernetes RBAC | https://kubernetes.io/docs/reference/access-authn-authz/rbac/ |
| Service Accounts | https://kubernetes.io/docs/concepts/security/service-accounts/ |
| Admission Controllers | https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/ |
| Kyverno Installation | https://kyverno.io/docs/installation/ |
| Kyverno Policies | https://kyverno.io/policies/ |
