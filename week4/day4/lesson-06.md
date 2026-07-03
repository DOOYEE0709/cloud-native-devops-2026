# 6교시: Kyverno Policy 2 - privileged와 hostPath 제한

## 실습 확인 기록

```bash
export NS=week4-security
export LAB=week4/day4/labs
```

① privileged/hostPath 금지 정책(Enforce) 적용

```bash
kubectl apply -f $LAB/kyverno/disallow-privileged-hostpath-enforce.yaml
kubectl get clusterpolicy disallow-privileged-hostpath-enforce
```
```text
clusterpolicy.kyverno.io/disallow-privileged-hostpath-enforce created

NAME                                   ADMISSION   BACKGROUND   READY   AGE   MESSAGE
disallow-privileged-hostpath-enforce   true        true         True    0s    Ready
```
정책 하나에 rule 2개(disallow-privileged, disallow-hostpath). Enforce.

② privileged + hostPath 나쁜 Pod 적용 → admission 거절 (두 rule 동시에 걸림)

```bash
kubectl apply -f $LAB/kyverno/bad-pod-privileged-hostpath.yaml
```
```text
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
resource Pod/week4-security/bad-privileged-hostpath was blocked due to the following policies
disallow-privileged-hostpath-enforce:
  disallow-hostpath: 'validation error: hostPath volumes are not allowed in week4-security.
    rule disallow-hostpath failed at path /spec/volumes/0/hostPath/'
  disallow-privileged: 'validation error: Privileged containers are not allowed in week4-security.
    rule disallow-privileged failed at path /spec/containers/0/securityContext/privileged/'
```
Pod 생성 거절. rule 2개가 각각 위반 경로(`/spec/volumes/0/hostPath/`, `/spec/containers/0/securityContext/privileged/`)를 정확히 짚어줌. etcd 저장 전에 막힘.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| privileged container가 위험한 이유는 | container isolation을 약화. host 자원·kernel 기능 접근 → 앱 취약점이 node 수준 영향으로 확대 |
| hostPath volume이 위험한 이유는 | node filesystem을 Pod에 mount(`path: /`면 호스트 루트). 앱이 node 파일에 직접 접근 → 사고 범위 확대 |
| 정책 하나에 rule이 2개인 이유는 | disallow-privileged / disallow-hostpath를 한 ClusterPolicy로 묶음. 위반 시 어떤 rule이 어느 경로에서 실패했는지 각각 보고 |
| `=(volumes)`와 `X(hostPath)` anchor의 의미는 | `=(volumes)`=volumes가 있을 때만 내부 검사(조건부), `X(hostPath)`=hostPath key가 있으면 실패. "volumes 자체 금지"가 아니라 "있다면 hostPath는 없어야 한다" |
| volumes 전체를 금지하면 안 되는 이유는 | hostPath 없는 정상 Pod(configMap/emptyDir 등)까지 막힘. anchor로 조건을 좁혀야 함 |
| 이런 예외(node exporter 등)는 어떻게 다루나 | namespace/ServiceAccount/image 제한 + change approval + runbook. 수업은 예외 없이 "일반 app namespace 차단" 기준 |

## notes

### privileged container 위험
| 위험 | 설명 |
|---|---|
| host 자원 접근 | node 수준 권한으로 이어질 수 있음 |
| kernel 기능 접근 | 일반 container보다 넓은 capability |
| 사고 범위 확대 | 앱 취약점이 node 영향으로 확대 |

모든 privileged가 나쁜 건 아니지만, 일반 application Pod엔 없어야 한다.

### hostPath volume 위험
node filesystem을 Pod에 mount. `path: /`면 호스트 루트 전체가 Pod에 노출.
```yaml
volumes:
  - name: host-root
    hostPath: { path: / }
```
운영에선 로그 수집 agent, CNI, CSI, node agent 같은 특수 workload에만 제한적으로 쓴다.

### 정책 구조 (rule 2개)
| rule | 막는 것 |
|---|---|
| disallow-privileged | `securityContext.privileged: true` |
| disallow-hostpath | `spec.volumes[].hostPath` |

### policy anchor — 조건부 검사 (중요)
```yaml
pattern:
  spec:
    =(volumes):          # volumes가 있을 때만 내부를 검사 (조건 anchor)
      - X(hostPath): "*"  # hostPath key가 있으면 실패 (negation anchor)
```
- `=(...)` = "이 필드가 있으면 그때만 검사" → 없는 정상 Pod는 통과
- `X(...)` = "이 key가 있으면 위반"
- 잘못된 방향: `volumes` 자체를 금지 → hostPath 없는 정상 Pod(configMap/emptyDir 등)까지 막힘. anchor로 "volumes가 있다면 그 안에 hostPath는 없어야 한다"로 좁혀야 한다.

### denial 메시지 읽기
| 항목 | 의미 |
|---|---|
| webhook 이름 | admission 단계에서 거절 |
| policy 이름 | 어떤 정책이 막았나 |
| rule 이름 | 어떤 rule이 위반됐나 |
| message | 수정 방향 |
| failed at path | 위반한 정확한 필드 경로 |

### 같은 "Pod 생성 실패"라도 원인 구분
| 오류 | 원인 |
|---|---|
| `cannot create resource pods` | RBAC 권한 없음 |
| `admission webhook denied` | 권한 있으나 manifest가 정책 위반 |
| `forbidden: violates PodSecurity` | Pod Security Admission 등 |
| `unknown field` | YAML schema 오류 |

### 예외 다루는 기준 (현업)
node exporter, CNI, CSI, log collector는 host 권한이 필요할 수 있다.
| 기준 | 설명 |
|---|---|
| namespace 제한 | kube-system, monitoring 등 |
| ServiceAccount 제한 | 특정 controller만 허용 |
| image 제한 | 승인된 registry/image만 |
| change approval | PR/승인 기록 |
| runbook | 왜 예외인지 문서화 |

### policy를 너무 세게 걸면
| 문제 | 대응 |
|---|---|
| 기존 앱 대량 위반 | Audit 먼저 |
| 메시지 불친절 | 수정 가능한 message 작성 |
| 예외 필요 | namespace/SA/image 조건 제한 |
| 개발팀 혼란 | 실패/해결 예시 제공 |

### 한 줄 요약
privileged와 hostPath는 일반 application namespace에서 막아야 할 대표적인 node 영향 위험이다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
