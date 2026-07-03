# 7교시: 권한과 정책 장애 분석

## 실습 확인 기록

```bash
export NS=week4-security
export LAB=week4/day4/labs
```

① 장애1 — readonly-viewer가 delete 시도 (RBAC / authorization 단계)

```bash
kubectl --as=system:serviceaccount:$NS:readonly-viewer -n $NS delete pod -l app=security-api
```
```text
Error from server (Forbidden): pods "security-api-…" is forbidden:
User "system:serviceaccount:week4-security:readonly-viewer"
cannot delete resource "pods" in API group "" in the namespace "week4-security"
```
→ `Forbidden`. authorization 단계. 조치: delete 권한이 정말 필요한지 검토(무조건 늘리지 않음).

② 장애2 — latest tag Pod (admission 단계 / Kyverno deny)

```bash
kubectl apply -f $LAB/kyverno/bad-pod-latest.yaml
```
```text
admission webhook "validate.kyverno.svc-fail" denied the request:
Pod/week4-security/bad-latest blocked by disallow-latest-enforce:
  require-explicit-image-tag: Do not use image tag latest. Match the release tag.
```
→ `admission denied`. 정책 disallow-latest-enforce. 조치: versioned tag로 수정.

③ 장애3 — privileged/hostPath Pod (admission 단계 / Kyverno deny)

```bash
kubectl apply -f $LAB/kyverno/bad-pod-privileged-hostpath.yaml
```
```text
admission webhook "validate.kyverno.svc-fail" denied the request:
Pod/week4-security/bad-privileged-hostpath blocked by disallow-privileged-hostpath-enforce:
  disallow-hostpath: hostPath volumes are not allowed … at /spec/volumes/0/hostPath/
  disallow-privileged: Privileged containers are not allowed … at /spec/containers/0/securityContext/privileged/
```
→ `admission denied`. 정책 disallow-privileged-hostpath-enforce. 조치: privileged와 hostPath 제거.

④ 첫 확인 명령 — 증상별로 어디부터 볼지

```bash
kubectl auth can-i delete pods --as=system:serviceaccount:$NS:readonly-viewer -n $NS   # Forbidden → 권한 확인
kubectl get clusterpolicy                                                              # admission deny → 정책 확인
kubectl get policyreport -A 2>/dev/null || true                                        # Audit 위반 확인
```
```text
# can-i delete pods → no
# clusterpolicy → disallow-latest-enforce / require-owner-label-audit / disallow-privileged-hostpath-enforce
# policyreport → bad-missing-owner FAIL 1 등
```

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 보안 실패의 두 갈래는 | (1) 권한 없음 → RBAC Forbidden (authorization) (2) 권한 있으나 object가 정책 위반 → admission deny |
| Forbidden이 뜨면 첫 명령은 | `kubectl auth can-i <verb> <resource> --as=<subject> -n <ns>` → 권한 여부 확인 후 Role/RoleBinding |
| admission denied가 뜨면 첫 명령은 | `kubectl get clusterpolicy` → 어떤 정책이 걸렸는지. 이어서 policy/rule/message/field 확인 |
| 정상 manifest가 deny되면 무엇을 의심하나 | manifest가 아니라 policy pattern/anchor 위치 실수(예: volumes 전체 금지). policy를 코드처럼 리뷰 |
| 개발팀에 나쁜 전달 vs 좋은 전달 | 나쁨="권한 풀어주세요"/"정책 때문에 안 됨". 좋음=필요한 verb·resource·scope 제시 / policy·rule·message·수정 field 전달 |
| 최소 권한 판단 기준은 | Forbidden이라고 무조건 권한을 늘리지 않음. 정말 그 verb/resource/scope가 필요한지 먼저 검토 |

## notes

### 장애를 두 갈래로 나누기
```text
권한 없음                 -> RBAC forbidden      (Role/RoleBinding을 봄)
권한 있으나 정책 위반     -> admission deny       (policy/manifest를 봄)
```
이 둘을 섞으면 해결이 늦어진다.

### 오류 메시지 대조
| 오류 | 단계 | 봐야 할 것 |
|---|---|---|
| `Forbidden: cannot delete resource pods` | authorization(RBAC) | can-i, Role, RoleBinding |
| `admission webhook denied ... disallow-latest-enforce` | admission(Kyverno) | clusterpolicy, rule, manifest |
| 정상 Pod가 deny | admission(정책 실수) | policy pattern/anchor 위치 |

### 첫 확인 명령표
| 증상 | 첫 명령 |
|---|---|
| Forbidden | `kubectl auth can-i ... --as=...` |
| admission denied | `kubectl get clusterpolicy` |
| policy report 위반 | `kubectl get policyreport -A` |
| webhook timeout | `kubectl -n kyverno get pod` |
| CRD 없음 | `kubectl get crd \| grep kyverno` |
| 정상 manifest도 deny | policy pattern/anchor 위치 확인 |

### 세 장애 분석 요약
| 장애 | 단계 | 오류 | 정책/원인 | 조치 |
|---|---|---|---|---|
| readonly delete | authorization | Forbidden | RBAC Role에 delete 없음 | 권한 필요성 검토 |
| latest Pod | admission | Kyverno deny | disallow-latest-enforce | versioned tag |
| privileged/hostPath | admission | Kyverno deny | disallow-privileged-hostpath-enforce | privileged·hostPath 제거 |

### 운영에서 좋은 대응
| 나쁜 대응 | 좋은 대응 |
|---|---|
| "권한 풀어주세요" | 필요한 verb/resource/scope 제시 |
| "정책 때문에 안 됨" | policy/rule/message와 수정 field 전달 |
| "일단 예외 주세요" | 왜/기간/범위 기록 |
| cluster-admin 부여 | 최소 권한 Role 설계 |

### 개발팀 전달 예시
```markdown
배포가 RBAC이 아니라 Kyverno admission 정책에서 거절되었습니다.
- namespace: week4-security
- resource: Pod/bad-latest
- policy: disallow-latest-enforce
- rule: require-explicit-image-tag
- message: Do not use image tag latest
- 수정: nginx:latest → nginx:1.27-alpine 처럼 버전 tag 사용
```

### W4D3 observability와 연결
| W4D3 도구 | W4D4 연결 |
|---|---|
| Event | admission deny event 확인 |
| Prometheus | policy violation metric |
| Grafana | Kyverno dashboard |
| Alert | 반복 violation alert |
| Runbook | 권한/정책 장애 분리 |

### 한 줄 요약
Forbidden은 권한 문제이고, admission denied는 object 내용이 정책을 위반했다는 신호다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
