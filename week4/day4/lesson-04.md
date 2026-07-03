# 4교시: Kyverno와 External Secrets Operator 설치/Preview

## 실습 확인 기록

```bash
export LAB=week4/day4/labs
```

① 설치 전 확인 — context / node / helm 준비 상태

```bash
kubectl config current-context
kubectl get nodes
helm version --short
```
```text
kind-paperclip-w4d2

NAME                           STATUS   ROLES           AGE   VERSION
paperclip-w4d2-control-plane   Ready    control-plane   45h   v1.36.1

v4.2.2+gb05881c
```
context / node Ready / helm 준비 완료.

② Kyverno Helm repo 추가 및 chart 검색

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm search repo kyverno/kyverno
```
```text
"kyverno" has been added to your repositories
Update Complete. ⎈Happy Helming!⎈

NAME                      CHART VERSION   APP VERSION   DESCRIPTION
kyverno/kyverno           3.8.1           v1.18.1       Kubernetes Native Policy Management
kyverno/kyverno-policies  3.8.1           v1.18.1       Pod Security Standards implemented as policies
```
chart 3.8.1 / app v1.18.1. (kyverno=엔진, kyverno-policies=미리 만든 정책 모음. 오늘은 엔진만 설치)

③ 설치에 쓸 values 확인 (긴 --set 대신 values 파일 사용)

```bash
cat $LAB/kyverno/values.yaml
```
```text
admissionController:   { replicas: 1 }
backgroundController:  { replicas: 1 }
cleanupController:     { replicas: 1 }
reportsController:     { replicas: 1 }
features:
  admissionReports:  { enabled: true }
  aggregateReports:  { enabled: true }
```
4개 컨트롤러를 각 1 replica로(로컬 kind라 최소 구성). 기본 3 replica면 리소스 부담 → 실습용으로 1로 낮춤. admission/aggregate report 기능 켬.

④ Helm으로 Kyverno 설치

```bash
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  -f $LAB/kyverno/values.yaml
```
```text
Release "kyverno" does not exist. Installing it now.
NAME: kyverno
NAMESPACE: kyverno
STATUS: deployed
REVISION: 1
Chart version: 3.8.1
Kyverno version: v1.18.1
설치된 컴포넌트: CRDs / Admission / Reports / Cleanup / Background controller
⚠️ replica<2 → HA 아님 (로컬 실습이라 의도된 구성)
```
STATUS deployed. replica 1이라 HA 경고가 뜨지만 로컬 실습에선 정상.

⑤ controller Pod 확인 + Ready 대기 (admission-controller가 Running인지가 핵심)

```bash
kubectl -n kyverno get pods
kubectl -n kyverno wait --for=condition=Ready pod --all --timeout=180s
```
```text
NAME                             READY   STATUS      RESTARTS   AGE
kyverno-admission-controller-…   1/1     Running     0          2m28s
kyverno-background-controller-…  1/1     Running     0          2m28s
kyverno-cleanup-controller-…     1/1     Running     0          2m28s
kyverno-reports-controller-…     1/1     Running     0          2m28s
kyverno-migrate-resources-…      0/1     Completed   0          100s   # 일회성 Job

pod/kyverno-admission-controller-… condition met
pod/kyverno-background-controller-… condition met
pod/kyverno-cleanup-controller-… condition met
timed out waiting for the condition on pods/kyverno-migrate-resources-jtlt9
timed out waiting for the condition on pods/kyverno-reports-controller-86b7c49987-d5m58
```
admission/background/cleanup은 condition met. timeout은 2개:
- migrate-resources → Completed 상태 일회성 Job이라 Ready 불가(정상, 무시)
- reports-controller → get pods에선 1/1 Running이었으나 wait가 migrate-resources에 붙잡힌 사이 Ready 조건을 제때 못 잡음. get pods로 재확인하면 Running.

`--all` 대신 label로 대상을 좁히면 방지.

```bash
kubectl -n kyverno wait --for=condition=Ready pod -l app.kubernetes.io/part-of=kyverno --timeout=180s
```

⑥ CRD 확인 — 없으면 policy manifest를 적용할 수 없음

```bash
kubectl get crd | grep kyverno
```
```text
clusterpolicies.kyverno.io
policies.kyverno.io
validatingpolicies.policies.kyverno.io
mutatingpolicies.policies.kyverno.io
cleanuppolicies.kyverno.io
policyexceptions.kyverno.io
... (reports.kyverno.io, generatingpolicies 등 총 19개)
```
정책 resource를 만들 수 있는 CRD가 설치됨. 5·6교시에서 clusterpolicies/policies.kyverno.io를 apply할 수 있음. CRD가 없으면 policy manifest 적용 불가.

⑦ webhook 확인 — admission controller가 API Server와 연결됐는지

```bash
kubectl get validatingwebhookconfiguration | grep kyverno
kubectl get mutatingwebhookconfiguration | grep kyverno
```
```text
# validating
kyverno-policy-validating-webhook-cfg      1    31m
kyverno-resource-validating-webhook-cfg    0    31m   # 아직 정책 없어 0
kyverno-cleanup/exception/ttl/... 등        1    31m
# mutating
kyverno-policy-mutating-webhook-cfg        1    31m
kyverno-resource-mutating-webhook-cfg      0    31m   # 아직 정책 없어 0
kyverno-verify-mutating-webhook-cfg        1    31m
```
webhook 등록 완료 → API Server ↔ Kyverno 배선됨. `resource-*-webhook-cfg`가 0인 건 정상: 아직 정책이 없어 검사할 대상이 없기 때문. 5·6교시에서 정책을 넣으면 이 값이 올라감.

⑧ (preview, 선택) External Secrets Operator — **오늘은 설치하지 않음**

강의 의도상 ESO는 개념 preview만 하고 실제 설치는 생략(강사도 미설치). 근거:
- lesson-04 원본: "실제 설치는 환경과 cloud credential 준비 상태에 따라 선택한다", "local kind에서는 AWS credential을 붙이지 않아 실제 조회까지 강제하지 않는다"
- lesson-05~08에서 ESO 사용 없음(언급 0회). 실제 secret store 선택 기준은 W5(AWS)에서 다시 다룸.

설치한다면 아래 형태였을 것(참고용, 미실행):

```bash
# (참고용, 오늘 실행하지 않음)
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace
kubectl -n external-secrets get deploy,pod
kubectl get crd | grep external-secrets   # externalsecrets/secretstores/clustersecretstores 등
```
ESO 개념·권한 모델은 아래 notes와 [[lesson-03]]의 ESO 권한 모델 참고. Kyverno(admission)와 달리 ESO는 ExternalSecret을 watch하는 reconciliation controller.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| RBAC이 있는데 Kyverno가 왜 또 필요한가 | RBAC은 "누가 할 수 있는가"만 본다. 권한 있는 사용자가 나쁜 manifest(latest, privileged, hostPath)를 배포하는 건 별개 문제 → Kyverno가 admission 단계에서 object 내용을 검사 |
| Kyverno는 요청 흐름의 어디서 동작하는가 | API Server admission 단계. `kubectl apply → API Server → Kyverno admission webhook → allow/deny` |
| 설치 직후 바로 policy를 넣지 않는 이유는 | Kyverno 자체가 건강한지(Pod Running / CRD / webhook / release deployed) 먼저 확인해야 함. 불안정한 상태에서 policy가 실패하면 원인이 policy인지 설치인지 구분 불가 |
| Kyverno와 ESO의 차이는 | Kyverno=manifest를 허용/거부/변형(admission 단계). ESO=외부 secret store 값을 K8s Secret으로 동기화(controller reconciliation loop). 둘 다 controller처럼 보이지만 위치·목적이 다름 |
| add-on 설치를 Helm으로 통일하는 이유는 | release/values/uninstall이 명확. remote YAML apply는 버전·출처·삭제 기준이 흐려지고, 수동 복붙은 재현이 어려움 |

## notes

### Kyverno를 왜 쓰는가 (RBAC과 다른 문제)
RBAC은 사용자의 권한을 제한한다. 하지만 **권한이 있는 사람이 나쁜 manifest를 배포하는 것은 별개 문제**다.
```yaml
image: nginx:latest          # 재현 불가능한 태그
securityContext:
  privileged: true           # 호스트 커널 권한
volumes:
  - hostPath: { path: / }    # 호스트 파일시스템 마운트
```
권한 있는 사용자도 이런 걸 만들 수 있다 → Kyverno가 admission 단계에서 object 내용을 검사해 막는다.

### Kyverno 동작 위치
```text
kubectl apply -> API Server -> Kyverno admission webhook -> allow/deny
```

### CRD란 (Custom Resource Definition)
쿠버네티스에 **새로운 종류(kind)의 리소스를 추가 등록**하는 것. 쿠버네티스는 원래 정해진 빌트인 종류만 안다(Pod, Service, Deployment, ConfigMap, Role...). Kyverno의 `ClusterPolicy`처럼 원래 모르는 종류는 CRD로 먼저 가르쳐야 쓸 수 있다.

```text
CRD 등록 전:  kubectl apply -f policy.yaml → error: no matches for kind "ClusterPolicy" ("그런 종류 몰라")
CRD 등록 후:  kubectl get clusterpolicy / apply -f policy.yaml → 동작
```

비유:
```text
빌트인 리소스 = 기본 메뉴판에 원래 있는 메뉴 (Pod, Service...)
CRD          = 메뉴판에 새 메뉴 종류를 등록하는 것 (clusterpolicies.kyverno.io)
커스텀 리소스 = 그 새 메뉴를 실제로 주문한 것 (kind: ClusterPolicy 하나하나)
```
- CRD로 **종류를 등록**해야 그 종류의 **실제 리소스**를 만들 수 있다 → "CRD 없으면 policy 적용 불가"의 의미.
- add-on들이 이 방식으로 자기 리소스를 추가: Kyverno=ClusterPolicy, ESO=ExternalSecret, Prometheus Operator=ServiceMonitor 등.
- 오늘 ⑥에서 본 `clusterpolicies.kyverno.io` = 등록된 종류(CRD), 5·6교시에 만들 `kind: ClusterPolicy` = 그 종류의 실제 리소스.

### Kyverno 컴포넌트
| Pod | 역할 |
|---|---|
| admission-controller | admission webhook 요청 처리 (가장 중요) |
| background-controller | background scan |
| cleanup-controller | cleanup policy 처리 |
| reports-controller | policy report 생성 |

버전에 따라 구성이 조금 다를 수 있음. 핵심은 **admission-controller가 Running인지**.

### 설치 후 건강 확인 4종 (policy 넣기 전에)
| 확인 | 이유 |
|---|---|
| Pod Running | webhook 처리 가능 |
| CRD 존재(clusterpolicies/policies.kyverno.io 등) | policy resource 생성 가능 |
| webhook 존재(validating/mutating) | API Server와 연결 |
| Helm release deployed | uninstall/upgrade 가능 |

불안정한 상태에서 policy 실패 시 원인 분리가 어렵다.

### helm install 인자 읽는 법 (release vs repo/chart)
```text
helm upgrade --install   kyverno    kyverno / kyverno
                           │          │       │
                        ① release   ② repo   ③ chart
                           별명       이름     이름
```
- ① release 이름 = 내가 붙이는 별명. "이 설치본을 뭐라 부를지". `helm list`에 뜨는 이름, uninstall할 때 쓰는 이름.
- ② repo 이름 = `helm repo add`로 등록한 상점.
- ③ chart 이름 = 그 상점 안의 차트.
- 읽는 법: "**②kyverno 상점의 ③kyverno 차트를 ①kyverno 라는 이름으로 설치**".
- 관례상 셋 다 같게 쓰는 경우가 많아 헷갈림. 다르게도 됨: `helm install my-engine kyverno/kyverno` → list엔 `my-engine`, 실제는 kyverno chart.
- release 이름이 따로 있는 이유: **같은 chart를 이름만 바꿔 여러 번 설치** 가능(`team-a-kyverno`, `team-b-kyverno`).

### Helm으로 설치하는 이유
| 방식 | 기준 |
|---|---|
| Helm | release/values/uninstall 명확 |
| remote YAML apply | 버전/출처/삭제 기준 흐려짐 |
| 수동 manifest 복붙 | 반복 재현 어려움 |

W4D1 이후 add-on 설치는 Helm으로 통일.

### Kyverno vs External Secrets Operator
| 도구 | 주 역할 | 동작 위치 |
|---|---|---|
| Kyverno | manifest 허용/거부/변형/검사 | API Server admission 단계 |
| ESO | 외부 secret store 값을 K8s Secret으로 동기화 | controller reconciliation loop |

```text
Kyverno: kubectl apply -> API Server -> admission webhook -> allow/deny
ESO:     ExternalSecret desired state -> ESO reconcile -> AWS Secrets Manager/SSM 조회 -> K8s Secret 생성/갱신
```

### ESO object (preview)
```text
SecretStore / ClusterSecretStore -> 어느 외부 provider를 볼 것인가
ExternalSecret                    -> 어떤 외부 key를 어떤 K8s Secret key로 동기화할 것인가
```
local kind에선 AWS credential을 안 붙여서 실제 조회는 강제하지 않음. 목표는 "operator가 어떤 권한·API object를 필요로 하는가" 이해. Secrets Manager vs SSM Parameter Store 선택 기준은 W5 AWS에서 재론.

### 한 줄 요약
Kyverno는 admission 단계에서 배포를 막고, ESO는 외부 secret을 K8s Secret으로 동기화하는 reconciliation controller다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| `wait --for=condition=Ready pod --all`이 controller met 후에도 안 끝나고 hang | `--all`이 `kyverno-migrate-resources`(Completed 상태의 일회성 Job Pod)까지 포함 → 그 Pod는 Ready가 될 수 없어 timeout까지 대기. Ctrl+C로 중단. controller는 모두 Ready. 대상을 `-l app.kubernetes.io/part-of=kyverno`로 좁히면 방지 |
