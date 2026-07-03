# 3교시: app Pod와 ServiceAccount

## 실습 확인 기록

```bash
export NS=week4-security
export LAB=week4/day4/labs
```

① sample workload가 어떤 ServiceAccount로 실행되는지 확인 (serviceAccountName / automountServiceAccountToken)

```bash
kubectl -n $NS get deploy security-api -o yaml | grep -E "serviceAccountName|automountServiceAccountToken"
```
```text
automountServiceAccountToken: false
serviceAccountName: app-runner
```
app-runner identity로 실행되지만 token은 자동 mount하지 않음(false).

② token을 mount하는 데모 Pod 생성

```bash
kubectl apply -f $LAB/rbac/token-mounted-pod.yaml
kubectl -n $NS get pod token-mounted-demo
```
```text
pod/token-mounted-demo created

NAME                 READY   STATUS    RESTARTS   AGE
token-mounted-demo   1/1     Running   0          4s
```

③ token이 mount된 Pod 안에서 token 파일 확인 (ca.crt / namespace / token 3개)

```bash
kubectl -n $NS exec token-mounted-demo -- ls /var/run/secrets/kubernetes.io/serviceaccount
```
```text
ca.crt
namespace
token
```
token이 mount된 Pod → 3개 파일 존재. Pod process가 이 token으로 API에 자신을 증명할 수 있음.

④ token이 없는 app Pod 확인 — automountServiceAccountToken: false라 directory 자체가 없음 (이 실패가 곧 성공 evidence)

```bash
pod="$(kubectl -n $NS get pod -l app=security-api -o jsonpath='{.items[0].metadata.name}')"
kubectl -n $NS exec "$pod" -- ls /var/run/secrets/kubernetes.io/serviceaccount
```
```text
ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
command terminated with exit code 1
```
token directory 자체가 없음 → automountServiceAccountToken: false의 결과. 이 실패는 장애가 아니라 의도한 보안 상태(성공 evidence).

⑤ 각 Pod가 어떤 SA를 쓰는지 한눈에 확인

```bash
kubectl -n $NS get pod -o custom-columns=NAME:.metadata.name,SA:.spec.serviceAccountName
```
```text
NAME                            SA
security-api-5fbdf88df7-8bchv   app-runner
token-mounted-demo              token-demo
```
Pod마다 이름 있는 SA(app-runner, token-demo)로 실행 → default SA를 쓰지 않음.

⑥ app-runner SA 자체 확인 — SA 레벨에도 token 차단이 걸려 있음(이중 차단)

```bash
kubectl -n $NS get sa app-runner -o yaml
```
```text
apiVersion: v1
automountServiceAccountToken: false
kind: ServiceAccount
metadata:
  name: app-runner
  namespace: week4-security
```
token 차단이 SA(app-runner) 레벨 + Deployment(security-api) 레벨 두 겹으로 걸림. SA에 걸어두면 이 identity를 쓰는 모든 Pod가 기본 token 없음 → Pod에서 설정 빠뜨려도 SA가 막아줌.

⑦ token 파일의 실체 확인 — Projected Volume으로 주입, token은 만료·자동교체

```bash
kubectl -n $NS describe pod token-mounted-demo
```
```text
Mounts:
  /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-ts6qs (ro)
Volumes:
  kube-api-access-ts6qs:
    Type:                    Projected
    TokenExpirationSeconds:  3607          # token 약 1시간마다 자동 갱신
    ConfigMapName:           kube-root-ca.crt   # ca.crt
    DownwardAPI:             true               # namespace
```
③에서 본 ca.crt/namespace/token 3개 파일은 이 projected volume으로 주입된 것. token은 무기한이 아니라 만료·rotation되는 단기 토큰이고, 읽기전용(ro)으로 마운트됨.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| ServiceAccount란 무엇인가 | Pod(앱)가 Kubernetes API를 호출할 때 쓰는 identity(신분). 사람의 kubeconfig에 해당하는 Pod용 계정 |
| automountServiceAccountToken: false의 의미는 | 이 앱은 app-runner identity로 실행되지만 Pod 안에 API token을 자동 mount하지 않는다 → API 호출이 필요 없으므로 문을 닫음 |
| app Pod의 token directory 확인이 실패했는데 왜 성공인가 | 의도한 보안 상태(token 미mount). 장애가 아니라 "token directory 없음"을 성공 evidence로 기록 |
| default ServiceAccount를 쓰면 안 되는 이유는 | identity 의도가 안 보이고, 권한을 붙이면 여러 Pod가 공유해 추적/audit이 어려움 → workload마다 이름 있는 SA |
| token mount와 RBAC 최소 권한을 함께 봐야 하는 이유는 | 앱에 RCE 취약점 + token mount면 공격자가 token을 읽어 API 호출 → RBAC 권한만큼 cluster에 영향. 둘 다 좁혀야 피해 최소화 |
| ESO가 app Pod와 권한 구조가 다른 점은 | ESO controller는 K8s API(ExternalSecret watch)와 외부 secret provider(AWS) 둘 다 접근. app Pod는 AWS를 직접 안 읽고 ESO가 동기화한 K8s Secret만 참조 |

## notes

### Pod와 identity
Kubernetes 안에서 도는 앱도 API를 호출할 수 있고, 그때 쓰는 신분이 ServiceAccount다.
```text
Pod -> ServiceAccount -> token -> Kubernetes API 호출 -> RBAC 판단
```
모든 앱이 API를 호출할 필요는 없다. 안 쓰는 앱에는 token을 mount하지 않는 편이 낫다.

### sample workload(security-api)의 핵심 설정
```yaml
serviceAccountName: app-runner
automountServiceAccountToken: false
```
"app-runner identity로 실행하되, Pod 안에 API token을 자동 mount하지 않는다"는 뜻.

### default ServiceAccount 위험
| 방식 | 문제 |
|---|---|
| serviceAccountName 생략 | 어떤 identity인지 의도가 안 보임 |
| default에 권한 부여 | 같은 namespace 여러 Pod가 권한 공유 |
| token 자동 mount | 앱 취약점이 API token 노출로 이어질 수 있음 |

운영 기준: **workload마다 이름 있는 ServiceAccount**.

### token mount 여부
- mount O: Pod 안 `/var/run/secrets/kubernetes.io/serviceaccount`에 `ca.crt / namespace / token` 3개 → Pod process가 token을 읽어 API 인증 가능
- mount X(`automountServiceAccountToken: false`): 위 directory 자체가 없음 → `No such file or directory`는 **의도된 보안 상태**(성공 evidence)

### 언제 token이 필요한가
| workload | token 필요 |
|---|---|
| 일반 web API | 대개 필요 없음 |
| API 안 쓰는 batch job | 필요 없음 |
| controller/operator | 필요 |
| external secret controller | 필요 |
| deployment automation agent | 필요 |

필요한 경우에도 최소 권한 Role을 붙인다.

### 위험 시나리오 (token mount + RBAC를 함께 보는 이유)
앱에 RCE 취약점이 있고 token이 mount되어 있다면, 공격자는 Pod 안에서 token을 읽어 Kubernetes API를 호출할 수 있다.

```text
app exploit(RCE)
  -> serviceaccount token read      (Pod 안의 token 파일 읽기)
  -> Kubernetes API call            (그 token으로 API 서버에 인증)
  -> RBAC 권한만큼 cluster 영향      (SA에 부여된 권한 범위까지 피해)
```

그래서 token mount와 RBAC 최소 권한은 **함께** 봐야 한다.
- token을 mount하지 않으면(`automountServiceAccountToken: false`) → 취약점이 있어도 읽을 token이 없음 (문을 닫음)
- token이 필요하더라도 SA에 최소 권한 Role만 붙이면 → token이 유출돼도 영향 범위가 좁음 (피해를 좁힘)

두 방어선이 겹쳐야 "token이 유출돼도 cluster가 크게 흔들리지 않는다"고 말할 수 있다.

### External Secrets Operator(ESO) 권한 모델 (preview)
app Pod와 성격이 다르다. operator는 K8s API와 외부 secret provider를 모두 다룬다.
```text
ESO Pod -> K8s API에서 ExternalSecret watch
        -> AWS Secrets Manager/SSM Parameter Store 조회
        -> Kubernetes Secret 생성/갱신
app Pod -> 동기화된 Kubernetes Secret을 참조 (AWS를 직접 안 읽음)
```
| 권한 | 설명 |
|---|---|
| Kubernetes RBAC | ExternalSecret 읽고 Secret 생성/갱신 |
| cloud IAM | AWS Secrets Manager/SSM 값 읽기 |
| app Pod 권한 | 만들어진 K8s Secret을 env/volume 참조 |

- Secrets Manager: rotation·DB credential·secret lifecycle 중요한 값
- SSM Parameter Store: 설정값·단순 secret·비용/운영 단순성 중요한 값
- 공통 원칙: Git엔 `ExternalSecret` 참조/mapping만, 실제 값은 외부 store에.
- workload identity: AWS IRSA/Pod Identity, GCP/Azure Workload Identity. local kind에선 구조만 preview.

### root / 회사 공용계정으로 막 작업하면 안 되는 이유 (실무 조언)
"root(또는 cluster-admin, 회사 공용계정)로 막 뭐 하지 마라. 회사 계정은 회사 계정이라 문제 생기면 수습이 힘들다" — 맞는 말. 오늘 최소 권한 원칙과 같은 이유.

| 이유 | 설명 |
|---|---|
| 사고 범위(blast radius) | root/cluster-admin은 뭐든 가능 → 실수 하나가 클러스터 전체·타 팀 서비스까지 번짐. 최소 권한은 실수해도 Forbidden으로 막힘 |
| 추적(audit) 불가 | 공용계정은 로그가 전부 같은 identity로 찍혀 "누가 바꿨나"를 못 찾음 → 원인·롤백 지점 못 잡아 수습 지연 |
| 회사 계정=조직 자산 | IAM 권한·비용·데이터가 조직 책임 범위. 개인이 넓게 쓰다 사고나면 되돌리기 어렵고 파급이 조직 전체 |

실무 원칙:
```text
- root / cluster-admin은 평소 작업용 X (비상시·최소한만)
- workload마다 이름 있는 ServiceAccount + 딱 필요한 만큼 Role
- 사람도 개인 식별되는 계정으로 최소 권한
- "편해서" 넓게 주지 않는다 → 사고나면 몇 배로 갚음
```

### 오해하기 쉬운 지점
| 오해 | 정리 |
|---|---|
| SA 만들면 자동으로 권한 생김 | RoleBinding이 있어야 함 |
| token 없으면 Pod 실행 안 됨 | API 호출 필요 없으면 없어도 됨 |
| default SA는 안전함 | 권한 붙으면 추적 어려움 |
| RBAC만 있으면 충분 | manifest 품질은 admission policy도 필요 |

### 한 줄 요약
ServiceAccount는 Pod의 identity이고, token mount는 앱이 Kubernetes API에 접근할 문을 열지 결정하는 설정이다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
