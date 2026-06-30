# 2교시: Helm 기본 개념

## 핵심 정리

### Helm을 왜 쓰는가 — add-on은 리소스 하나가 아니다
- metrics-server만 해도 Deployment + Service + ServiceAccount + RBAC + APIService가 함께 필요. ingress-nginx·Prometheus·Argo CD·Istio는 더 복잡.
- 원격 YAML 그대로 적용(`kubectl apply -f url`)은 빠르지만 운영 질문에 약함:

| 질문 | remote YAML만 쓸 때 문제 |
|---|---|
| 어떤 버전 설치했나 | URL/commit 추적 안 하면 애매 |
| 어떤 설정 바꿨나 | 긴 명령·임시 수정이 사라짐 |
| 다시 설치 가능한가 | 재현성 낮음 |
| 변경 이력 어디 있나 | release revision 없음 |
| 제거는 어떻게 | label 추적 실패 시 리소스 잔존 |

- ⭐ Helm은 이걸 **release + values**로 정리. values를 Git에 남기면 "우리 팀은 이 add-on을 이 옵션으로 설치한다"가 **문서가 아니라 코드로** 남음.

### Helm 5대 용어
| 용어 | 설명 | 예시 |
|---|---|---|
| **Chart** | 설치 패키지 | `metrics-server/metrics-server` |
| **Repository** | chart 저장소 | `https://kubernetes-sigs.github.io/metrics-server/` |
| **Release** | cluster에 설치된 chart instance | `metrics-server` |
| **Values** | chart에 넣는 설정 | `values.yaml` |
| **Revision** | release 변경 이력 | `helm history` |

### ⭐ Chart ≠ Release (가장 헷갈리는 지점)
```text
Chart   = 설치 가능한 패키지 (붕어빵 틀)
Release = chart를 cluster에 설치한 결과물 (구운 붕어빵)
```
- **같은 chart를 여러 release로** 설치 가능 (staging/production ingress를 다른 namespace·values로).

| release name 예 | 의미 |
|---|---|
| `metrics-server` | cluster 공통 add-on |
| `ingress-nginx` | 기본 ingress controller |
| `payments-api` / `payments-api-canary` | app / canary release |

### Metric Server 설치 — 기본 흐름 (repo add → update → install → list)
```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/   # ① repo 등록
helm repo update metrics-server                                                  # ② 최신 chart 목록 갱신
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system   # ③ 설치(or 갱신)
helm list -n kube-system                                                         # ④ release 확인
```

| 단계 | 명령 | 하는 일 |
|---|---|---|
| ① add | `helm repo add <name> <url>` | chart 저장소를 로컬에 등록 (별칭=`metrics-server`) |
| ② update | `helm repo update <name>` | 등록된 repo의 chart 인덱스를 최신화 |
| ③ install | `helm upgrade --install <release> <repo/chart> -n <ns>` | chart로 release 설치(있으면 갱신) |
| ④ list | `helm list -n <ns>` | 그 namespace의 release 목록 확인 |

- ⚠️ 여기선 `-f values.yaml` 없이 **chart 기본값**으로 설치. 운영에선 values file을 붙임(아래 `upgrade --install` 참고).
- 이 4단계가 모든 add-on 설치의 공통 패턴 → **3교시 "Helm 공통 설치 루프"**에서 표준화.

### Helm은 template engine — values가 manifest를 렌더링
```text
chart template + values.yaml
  → rendered Kubernetes manifests
  → API Server apply
  → release revision 기록
```
- Helm을 쓴다 = 설치 명령을 외우는 게 아니라 **"설정 파일 + 변경 이력을 남기는 설치 방식"**을 쓰는 것.

### values는 옵션이 아니라 운영 정책
```yaml
replicaCount: 2
resources:
  requests: { cpu: 100m, memory: 128Mi }
  limits:   { cpu: 500m, memory: 512Mi }
```
- "이 add-on이 최소 얼마 요구하고 최대 얼마 허용하나"라는 **운영 결정**. 그래서 `--set`으로만 남기면 재현이 어려움 → **values file을 Git에**.

### ⭐ `install` 말고 `upgrade --install`
```bash
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  -f week4/day1/labs/helm-metrics-server/values.yaml
```

| 부분 | 의미 |
|---|---|
| `upgrade --install` | release 있으면 갱신, 없으면 설치 (멱등) |
| `metrics-server` | release name |
| `metrics-server/metrics-server` | repo/chart |
| `--namespace kube-system` | 설치 namespace |
| `-f values.yaml` | repo에 남긴 설정 파일 |

### revision & rollback
```bash
helm history metrics-server -n kube-system
helm rollback metrics-server 1 -n kube-system
```
- release 변경마다 **revision 기록** → "무엇을 언제 바꿨나" 확인, 문제 시 이전 revision으로 rollback.
- ⚠️ rollback은 **Kubernetes manifest 상태**(Deployment/Service/ConfigMap)를 되돌리는 것. **DB schema·외부 상태는 별도 전략** 필요. (W3D5 7교시 rollout undo와 같은 한계)

### ⚠️ Helm이 모든 걸 해결하진 않는다
| 오해 | 실제 확인 |
|---|---|
| `helm install` 성공 = 앱 성공 | `kubectl get pod`/`logs` 확인 필요 (STATUS=deployed ≠ Pod Ready) |
| `helm uninstall` = 전부 삭제 | PVC/CRD/cluster-scoped resource는 남을 수 있음 |
| values file만 보면 실제 설정 안다 | `helm get values`/`helm get manifest` 확인 |
| rollback = 모든 상태 복귀 | DB·외부 시스템·데이터는 별도 관리 |

- Helm 명령과 **반드시 같이** 볼 것:

| 확인 | 명령 |
|---|---|
| release 목록 | `helm list -A` |
| release 상태 | `helm status <release> -n <ns>` |
| 적용 values | `helm get values <release> -n <ns>` |
| 생성 리소스 | `kubectl get all -n <ns>` |
| 이력 | `helm history <release> -n <ns>` |

### remote YAML vs Helm
| 방식 | 장점 | 한계 |
|---|---|---|
| `kubectl apply -f remote-url` | 빠르고 단순 | values·release·rollback·uninstall 추적 약함 |
| `helm upgrade --install -f values.yaml` | 재현성·변경 이력·제거 좋음 | chart·values 이해 필요 |

### 오늘 계속 되돌아올 Helm 판단 문장
```text
무엇을 설치했나?   → chart
어디에 설치했나?   → namespace
어떤 이름으로?     → release
어떤 설정으로?     → values
어떻게 바뀌었나?   → revision/history
정말 동작하나?     → kubectl evidence
```

### 한 줄 요약
> **Helm은 add-on을 설치하는 명령이 아니라, 설치 설정과 변경 이력을 남기는 운영 표준이다.** 멋있어서가 아니라 **다시 설명하고 되돌리기 위해** 쓴다.

## 실습 확인 기록

### ① metrics-server 설치 (repo add → update → upgrade --install → list)
```text
$ helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
"metrics-server" has been added to your repositories

$ helm repo update metrics-server
...Successfully got an update from the "metrics-server" chart repository
Update Complete. ⎈Happy Helming!⎈

$ helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system
Release "metrics-server" does not exist. Installing it now.    ← release 없어서 "install" 분기
NAME: metrics-server
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
NOTES:
  Chart version: 3.13.1
  App version:   0.8.1
  Image tag:     registry.k8s.io/metrics-server/metrics-server:v0.8.1

$ helm list -n kube-system
NAME            NAMESPACE     REVISION  UPDATED                STATUS    CHART                  APP VERSION
metrics-server  kube-system   1         2026-06-30 16:15:10    deployed  metrics-server-3.13.1  0.8.1
```
- 읽는 포인트:
  - **`Release "metrics-server" does not exist. Installing it now.`** = `upgrade --install`의 멱등성. release가 없어서 **install로 분기**. 다시 실행하면 "upgrade"로 분기됨.
  - **STATUS=deployed, REVISION 1** = Helm 관점 배포 성공. 첫 설치라 revision 1.
  - **CHART `metrics-server-3.13.1` vs APP VERSION `0.8.1`** = chart 버전(패키징)과 app 버전(실제 metrics-server)이 **다름**. (2교시 용어: chart ≠ app)
  - ⚠️ **STATUS=deployed ≠ Pod Ready.** Helm은 "선언이 받아들여짐"까지만 보장 → 아래 ②로 actual 확인 필요.

### ② values 적용 = upgrade(REVISION 2) — kind 인증 우회
```text
$ helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system \
    -f week4/day1/labs/helm-metrics-server/values.yaml
Release "metrics-server" has been upgraded. Happy Helming!   ← 이번엔 "install"이 아니라 "upgrade"로 분기
NAME: metrics-server
NAMESPACE: kube-system
STATUS: deployed
REVISION: 2                                                  ← revision 1(기본) → 2(values 적용)
DESCRIPTION: Upgrade complete
```
- 읽는 포인트:
  - **"has been upgraded"** = ①에서 install(rev 1)된 release가 이미 있어, 같은 명령에 `-f values.yaml`만 붙이니 **upgrade로 분기**(rev 2). → `upgrade --install` 멱등성의 실증.
  - **왜 values를 붙였나** = ① 기본 설치는 **kind에서 kubelet 인증서 검증 실패**로 metric이 안 나옴. values의 `--kubelet-insecure-tls`로 우회.
  - 적용된 values (`labs/helm-metrics-server/values.yaml`):
```yaml
args:
  - --kubelet-insecure-tls                                        # kubelet 인증서 검증 건너뜀 (kind 전용)
  - --kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP  # node 접속 주소 우선순위
resources:
  requests: { cpu: 50m, memory: 64Mi }
  limits:   { cpu: 200m, memory: 256Mi }
```
  - revision 1 → 2로 **"무엇이 바뀌었는지" 이력이 남음** (`helm history`로 확인). 문제 시 `helm rollback`으로 1로 되돌릴 수 있음.

### ③ history(revision 이력) + Pod Ready 확인 (deployed = Pod도 진짜 떴나)
```text
$ helm history metrics-server -n kube-system
REVISION  UPDATED                   STATUS      CHART                  APP VERSION  DESCRIPTION
1         Tue Jun 30 16:15:10 2026  superseded  metrics-server-3.13.1  0.8.1        Install complete
2         Tue Jun 30 16:22:07 2026  superseded  metrics-server-3.13.1  0.8.1        Upgrade complete
3         Tue Jun 30 16:24:59 2026  deployed    metrics-server-3.13.1  0.8.1        Upgrade complete   ← 현재 활성

$ kubectl -n kube-system get pod -l app.kubernetes.io/name=metrics-server
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-5fc94cbbc8-tdltq   1/1     Running   0          2m59s        ← ⭐ READY 1/1 (인증 우회 성공)
```
- 읽는 포인트:
  - **revision마다 STATUS가 다름**: 과거(`1`,`2`)는 `superseded`(밀려남), 현재(`3`)만 `deployed`(활성). → 한 release에 **하나의 활성 revision** + 나머지는 이력으로 보존.
  - **upgrade를 N번 → revision N개** 누적. 이게 `helm rollback <revision>`의 되돌릴 기준점. (W3D5 7교시 rollout revision과 같은 발상)
  - ⭐ **Pod `READY 1/1`** = `--kubelet-insecure-tls` 덕에 kubelet 스크랩 성공 → metrics-server가 진짜 동작. **`STATUS=deployed`(Helm) + `READY 1/1`(kubectl) 둘 다 확인**해야 "정말 됐다".
  - 만약 values 없이(rev 1) 뒀다면 Pod는 떠도 metric을 못 긁어 **`READY 0/1`**로 머물렀을 것.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Chart와 Release 차이는? | Chart=설치 패키지(틀), Release=cluster에 설치된 instance(결과물). 같은 chart로 여러 release 가능 |
| `kubectl apply -f url` 대신 Helm 쓰는 이유는? | values·release·revision·rollback·uninstall을 추적/재현 가능하게 (운영 지식을 코드로) |
| `upgrade --install`을 쓰는 이유는? | 멱등 — release 있으면 갱신, 없으면 설치. 스크립트/자동화에 안전 |
| `STATUS=deployed`면 앱도 정상인가? | 아님. Helm release가 배포됐다는 뜻. Pod Ready는 `kubectl get pod`로 따로 확인 |
| values를 `--set` 말고 file로 남기는 이유는? | 재현성. 팀원이 같은 설정을 다시 설치 가능 (Git에 운영 정책으로 남음) |
| helm rollback의 한계는? | manifest 상태만 되돌림. DB schema·외부 상태·데이터는 별도 전략 |

## notes

### Evidence Note
```markdown
# W4D1S2 Helm 개념
- chart와 release 차이:
- values file에 남겨야 하는 이유:
- `upgrade --install`을 쓰는 이유:
- Helm으로도 해결되지 않는 것:
```

### Helm도 "선언 vs 구현" 패턴 (W3D5 연결)
- **values + chart = desired**(원하는 설정), **release/revision = 적용 이력**, **Pod = actual**.
- `helm install` 성공(deployed)은 "선언이 받아들여짐"이지 "Pod가 Ready"가 아님 → 항상 `kubectl get pod`로 actual 확인. (W3D5 "Service=선언 vs kube-proxy=구현", "200이 나와도 배포 성공 아님"과 같은 결)

### ⚠️ kind에서 metrics-server가 인증 실패하는 이유 + values 옵션
metrics-server는 각 node의 **kubelet에 HTTPS로 접속해** CPU/메모리를 긁어온다. 이때 TLS 인증서를 검증하는데, kind에선 이게 막힌다.

```text
metrics-server → (HTTPS) → kubelet /metrics
                  └ kubelet 인증서가 cluster CA로 서명됐는지 검증
실제 cluster(EKS 등): 제대로 서명 → 통과 ✅
kind            : kubelet이 self-signed 인증서 → x509 검증 실패 ❌ → 스크랩 실패 → metric 없음 → `kubectl top` 안 됨
```

그래서 values.yaml에 두 옵션을 넣는다:

| 옵션 | 역할 | 왜 kind에 필요 |
|---|---|---|
| `--kubelet-insecure-tls` | kubelet 인증서 검증을 **건너뜀** | kind의 self-signed 인증서 x509 오류 우회 |
| `--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP` | node에 접속할 **주소 우선순위** 지정 | kind node를 InternalIP 우선으로 안정적으로 찾게 함 (기본 Hostname이 DNS로 안 풀릴 수 있음) |

- ⚠️ `--kubelet-insecure-tls`는 **인증서 검증을 끄는 것**이라 **로컬/kind 실습 전용.** 운영 cluster에선 절대 쓰지 말 것(중간자 공격 위험). → 그래서 **dev values / prod values를 나눈다** (2교시 "values=운영 정책"의 실제 사례).
- values엔 `resources`(requests/limits)도 함께 선언 → add-on도 자원 기준을 가진다(6교시 연결).

### `helm list`와 `kubectl get`은 보는 층이 다르다
- `helm list -A` = **Helm이 관리하는 release**만 보임 (Helm으로 설치한 것).
- `kubectl get all -n <ns>` = 그 release가 만든 **실제 Kubernetes 리소스**.
- 둘을 같이 봐야 "설치는 됐는데 Pod가 안 떴다" 같은 상황을 잡음.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
