# 5교시: Kyverno Policy 1 - latest 금지와 required label

## 실습 확인 기록

```bash
export NS=week4-security
export LAB=week4/day4/labs
```

① Audit 정책 적용 (owner label 요구, 단 막지는 않음)

```bash
kubectl apply -f $LAB/kyverno/require-owner-label-audit.yaml
kubectl get clusterpolicy require-owner-label-audit
```
```text
clusterpolicy.kyverno.io/require-owner-label-audit created

NAME                        ADMISSION   BACKGROUND   READY   AGE   MESSAGE
require-owner-label-audit   true        true         True    4s    Ready
```
정책 생성 + READY True. ADMISSION true=admission 요청 검사, BACKGROUND true=기존 리소스도 background scan.

② owner label 없는 Pod 적용 — Audit라서 생성은 됨(위반은 기록)

```bash
kubectl apply -f $LAB/kyverno/bad-pod-missing-owner.yaml
```
```text
pod/bad-missing-owner created
```
owner label 없는 위반 Pod인데도 생성됨 → Audit라서 막지 않음(정상).

③ policy report 확인 — Audit 위반이 기록됐는지

```bash
kubectl get policyreport -A 2>/dev/null || true
kubectl get clusterpolicyreport -A 2>/dev/null || true
```
```text
NAMESPACE        KIND         NAME                     PASS   FAIL
week4-security   Pod          bad-missing-owner        0      1     # 위반 기록(생성은 됨)
week4-security   Pod          token-mounted-demo       1      0     # owner label 있음
week4-security   Pod          security-api-...         1      0
week4-security   ReplicaSet   security-api-...         1      0
week4-security   Deployment   security-api             1      0
# clusterpolicyreport: 비어있음(정상)
```
- bad-missing-owner = PASS 0 / FAIL 1 → Audit가 "안 막되 기록"함을 증명. 기존 리소스는 owner label이 있어 PASS.
- policyreport는 reports-controller가 비동기로 채움 → apply 직후엔 안 보이고 수십 초 뒤 반영.
- clusterpolicyreport 비어있는 건 정상: policyreport=namespace 리소스, clusterpolicyreport=cluster 리소스. 오늘 대상은 모두 namespace 리소스(Pod 등).

④ Enforce 정책 적용 (latest tag 금지, 위반이면 거절)

```bash
kubectl apply -f $LAB/kyverno/disallow-latest-enforce.yaml
kubectl get clusterpolicy disallow-latest-enforce
```
```text
clusterpolicy.kyverno.io/disallow-latest-enforce created

NAME                      ADMISSION   BACKGROUND   READY   AGE   MESSAGE
disallow-latest-enforce   true        true         True    12s   Ready
```
Enforce 정책 생성 + READY True. 이제 latest tag Pod는 admission 단계에서 거절됨.

⑤ latest tag Pod 적용 — Enforce라서 admission에서 거절(Forbidden 아님, admission deny)

```bash
kubectl apply -f $LAB/kyverno/bad-pod-latest.yaml
```
```text
Error from server: error when creating "bad-pod-latest.yaml":
admission webhook "validate.kyverno.svc-fail" denied the request:
resource Pod/week4-security/bad-latest was blocked due to the following policies
disallow-latest-enforce:
  require-explicit-image-tag: 'validation failure: Do not use image tag latest.
    Match the web application version or release tag.'
```
Enforce라서 Pod 생성 거절(created 없음). 에러가 `admission webhook denied`(admission 단계)지 `Forbidden`(RBAC)이 아님 → 권한은 있으나 object 내용이 정책 위반. 메시지가 "무엇을/왜/어떻게"까지 알려줘 개발자가 바로 수정 가능.

⑥ 정상 Pod 적용 — tag 고정 + owner label 있음 → 통과

```bash
kubectl apply -f $LAB/kyverno/good-pod.yaml
kubectl -n $NS get pod good-versioned-owner
```
```text
pod/good-versioned-owner created

NAME                   READY   STATUS    RESTARTS   AGE
good-versioned-owner   1/1     Running   0          3s
```
owner label + 고정 tag 둘 다 만족 → 통과(Running). 규칙을 지키면 막히지 않음.

⑦ (4교시 연결) 정책 적용 후 resource webhook이 활성화됐는지 — 0에서 올라감

```bash
kubectl get validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg -o jsonpath='{.webhooks[*].name}'; echo
```
```text
validate.kyverno.svc-fail
```
4교시에선 이 webhook의 rule 수가 0이었음(정책 없어서). 정책을 넣으니 `validate.kyverno.svc-fail` webhook이 활성화됨 → "정책이 있어야 Kyverno가 요청을 실제로 가로챈다"를 증명. ⑤ 거절 에러의 webhook 이름과 동일.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Audit와 Enforce의 차이는 | Audit=위반을 기록만 하고 생성은 허용(validationFailureAction: Audit). Enforce=위반 object를 admission 단계에서 거절(Enforce) |
| latest tag를 왜 막는가 | 재현·rollback·audit이 어려움. 같은 tag가 다른 image를 가리킬 수 있어 배포 시점 artifact 추적 불가 → version/release tag로 고정 |
| owner label을 왜 강제하는가 | 장애 시 "이 Pod는 누가 책임지나"를 바로 알아야 함. owner=담당 팀/사람 |
| latest Pod 거절은 RBAC 문제인가 | 아니다. 요청자는 Pod 생성 권한이 있었으나 object 내용이 policy 위반 → admission deny (Forbidden=RBAC과 구분) |
| 운영에서 Audit→Enforce로 바꾸는 이유는 | 바로 Enforce면 기존 배포가 막힘. Audit로 영향 범위 확인 → 수정/예외 정리 → 공지 → Enforce 전환 → 실패 runbook |
| 좋은 정책 실패 메시지란 | 개발자가 바로 고칠 수 있는 문장. "policy failed"(나쁨) vs "Do not use image tag latest. Match the release tag."(좋음) |

## notes

### 왜 label을 강제하는가
장애 시 "이 Pod는 누가 책임지는가"를 바로 알아야 한다.
| label | 운영 용도 |
|---|---|
| `owner` | 담당 팀/사람 |
| `app` | 서비스 식별 |
| `env` | dev/stage/prod 구분 |
| `version` | 배포 버전 |
| `cost-center` | 비용 배부 |

오늘은 단순하게 `owner` label만 요구.

### Audit vs Enforce (validationFailureAction)
정책이 위반을 발견했을 때 **어떻게 반응할지** 정하는 모드. 정책 YAML의 `validationFailureAction: Audit | Enforce` 한 줄로 결정.

| 모드 | 동작 | 용도 |
|---|---|---|
| Audit | 위반 기록, 생성은 허용 | 영향 범위·기존 위반 파악 |
| Enforce | 위반 object를 admission에서 거절 | 실제 차단 |

```text
Audit:   apply → 위반이지만 생성됨 → policyreport에 기록
Enforce: apply → 위반이면 admission webhook denied → 생성 거절
```

비유 (공항 보안검색대):
```text
Audit   = CCTV 녹화만. 위험물 있어도 통과시킴. 기록은 남음
Enforce = 검색대에서 위험물 발견 시 그 자리에서 막음
```
왜 두 모드가 있나: 바로 Enforce로 켜면 이미 돌던 배포가 갑자기 다 막혀 사고 남. 그래서 Audit로 먼저 관찰 → 위반 파악·수정 → 공지 → Enforce 전환 순서(아래 "Audit → Enforce 전환 권장 흐름" 참고).

### latest tag를 막는 이유
| 문제 | 설명 |
|---|---|
| 재현 어려움 | 같은 tag가 다른 image를 가리킬 수 있음 |
| rollback 어려움 | 어떤 버전으로 돌아갈지 불명확 |
| audit 어려움 | 배포 시점 artifact 추적 어려움 |
| 캐시 혼란 | node/image cache와 registry 상태 엇갈림 |

Week3처럼 image tag는 web application version 또는 release tag와 맞춘다.

### 테스트 Pod 설계 — 각 파일이 정책 하나씩만 위반
원인을 격리하려고 파일마다 **딱 한 정책만** 위반시키고 나머지는 정상으로 둔다.

| 파일 | owner label | image tag | 위반 정책 | 결과 |
|---|---|---|---|---|
| bad-missing-owner | ❌ 없음 | ✅ nginx:1.27-alpine | require-owner-label (Audit) | 생성됨 + report FAIL |
| bad-latest | ✅ owner: platform | ❌ nginx:latest | disallow-latest (Enforce) | admission denied |
| good-pod | ✅ owner: platform | ✅ nginx:1.27-alpine | 없음 | 통과 |

- `bad-latest`에 owner label을 **일부러 채워둔** 이유: owner까지 빠뜨리면 두 정책을 동시에 위반해 "latest 때문인지 owner 때문인지" 구분 불가. 순수하게 latest만 문제 삼으려고.
- 한 번에 하나씩 검증하는 방식 = 2교시에서 list는 되고 delete만 막히는 걸 따로 확인한 것과 동일한 실험 설계.

### 정상 Pod 기준 (good-pod)
| 조건 | 값 |
|---|---|
| image tag | `nginx:1.27-alpine` (고정) |
| owner label | `owner: platform` |
| privileged | 없음 |
| hostPath | 없음 |

### Audit → Enforce 전환 권장 흐름
```text
Audit 적용 -> report 확인 -> 예외/수정 대상 정리 -> 팀 공지 -> Enforce 전환 -> 실패 runbook 작성
```
운영에서 바로 Enforce로 넣으면 기존 배포가 막힐 수 있다.

### 정책 실패 메시지 작성 기준
```text
나쁨:  policy failed
좋음:  Do not use image tag latest. Match the web application version or release tag.
```
개발자가 메시지만 보고 바로 수정할 수 있어야 한다.

### admission deny vs Forbidden (1교시 연결)
- Forbidden = authorization(RBAC) 단계. "권한 없음"
- admission webhook denied = admission 단계. "권한은 있으나 object 내용이 정책 위반" ← latest Pod 거절이 이것

### 한 줄 요약
Audit는 위반을 보이게 만들고, Enforce는 위반 배포를 막는다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
