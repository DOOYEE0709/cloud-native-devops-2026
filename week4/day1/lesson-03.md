# 3교시: Helm 공통 설치 루프

## 핵심 정리

### 공통 설치 루프 — Week4 내내 반복
```text
1. chart repo 등록 (repo add)
2. chart repo update
3. values file 확인
4. helm upgrade --install
5. helm list/status/history 확인
6. kubectl로 실제 리소스 확인
7. 필요하면 rollback 또는 uninstall
```
- ⭐ 이 루프는 metrics-server에서 안 끝남. Week4 add-on 전부 **같은 패턴**:

| Day | add-on | 연결 |
|---|---|---|
| W4D1 | metrics-server | resource metric, `kubectl top` |
| W4D2 | ingress-nginx | 외부 traffic 진입점 |
| W4D3 | kube-prometheus-stack | 관찰 stack |
| W4D4 | Kyverno | admission policy |
| W4D5 | Argo CD/Istio/Kiali | GitOps·mesh |

→ 오늘 루프를 허술히 넘기면 뒤 4일이 흔들림.

### ① repo add/update + search
```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm search repo metrics-server      # chart가 보이는지 확인
```
- chart가 안 보이면 **설치 명령보다 repo 등록 상태를 먼저** 본다.
- ⚠️ **Chart Version ≠ App Version**:

| 버전 | 의미 |
|---|---|
| Chart Version | chart template/values **구조**의 버전 (예: 3.13.1) |
| App Version | 실제 metrics-server **app**의 버전 (예: 0.8.1) |

### ② helm template — 설치 전에 "어떤 YAML이 만들어지나" 미리보기
```bash
helm template metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  -f week4/day1/labs/helm-metrics-server/values.yaml \
  | grep -E "kind: Deployment|kind: APIService|--kubelet-insecure-tls"
```
- `helm template` = **API Server에 적용 안 함.** values가 chart에 들어가 **렌더링된 manifest를 눈으로** 확인하는 용도(dry-run 성격).
- ⭐ **"values에 썼다 = 실제 반영됐다"라고 가정하지 않는다.** template 결과로 확인. (내가 쓴 `--kubelet-insecure-tls`가 정말 Deployment args에 박혔는지)

### ③ 설치 — install vs upgrade 분기
```bash
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  -f week4/day1/labs/helm-metrics-server/values.yaml
```
- 첫 설치: `Release ... does not exist. Installing it now.` (REVISION 1)
- 이미 있음: `Release ... has been upgraded.` (REVISION 2+)
- ⚠️ 설치 직후 "성공"이라 말하지 않는다 → release와 **Pod 상태를 따로** 확인.

### ⭐ 설치 후 확인할 레이어 (Helm 성공 ≠ 앱 동작)
| 레이어 | 명령 | 의미 |
|---|---|---|
| Helm release | `helm status` | chart가 release로 설치됐나 |
| Kubernetes object | `kubectl get deploy,pod` | object가 만들어졌나 |
| Pod readiness | `kubectl get pod` | container가 준비됐나 (`READY 1/1`) |
| API aggregation | `kubectl get apiservice` | Metrics API가 붙었나 |
| 사용자 명령 | `kubectl top` | 실제 metric 조회되나 |

- `helm status`가 deployed여도 Pod가 Ready 아닐 수 있음 → **레이어를 위에서 아래로** 내려가며 확인.

### ④ values 확인 — "내가 어떤 설정으로 깔았는지" 재현
```bash
cat week4/day1/labs/helm-metrics-server/values.yaml    # repo의 values (의도)
helm get values metrics-server -n kube-system          # 실제 적용된 values
helm get manifest metrics-server -n kube-system        # 렌더된 최종 manifest
```
- 두 결과가 **다르면** 누가 `--set`으로 추가했거나 다른 파일로 upgrade한 것 → **운영 인수인계에서 자주 문제.**

### ⑤ rollback & uninstall
```bash
helm history metrics-server -n kube-system
helm rollback metrics-server 1 -n kube-system     # revision 1로 되돌림 (새 revision 생성)
helm uninstall metrics-server -n kube-system      # release 리소스 제거
```
- 현재 적용 revision = `STATUS=deployed`인 행. rollback 하면 **새 revision이 하나 더** 생기며 이전 manifest 재적용.
- ⚠️ uninstall 해도 **PVC/CRD/cluster-scoped는 남을 수 있음** → chart 정리 정책 확인.

### 실패 상황별 판단 / 실수 패턴
| 상황 | 먼저 볼 것 |
|---|---|
| chart 못 찾음 | `helm repo list`, `helm search repo` (repo/index 문제) |
| release 이미 있음 | `helm history`, `helm get values` |
| Pod Pending | `kubectl describe pod` (scheduling/resource) |
| Pod CrashLoop | `kubectl logs` |
| APIService False | `kubectl describe apiservice` |

| 실수 | 증상 | 해결 |
|---|---|---|
| repo update 생략 | chart 못 찾음 | `helm repo update` |
| namespace 혼동 | release 안 보임 | `helm list -A` |
| release name 중복 | 다른 설정이 덮임 | naming 기준 정리 |
| values file 미보관 | 재현 불가 | repo에 values 저장 |
| uninstall만 믿음 | 일부 잔존 | `kubectl get all,cm,secret,crd -A` |

### 성공 기준
| 기준 | 명령 | 성공 출력 |
|---|---|---|
| release 생성 | `helm list -n kube-system` | `metrics-server`, `deployed` |
| Pod 준비 | `kubectl -n kube-system get pod -l app.kubernetes.io/name=metrics-server` | `READY 1/1` |
| API 등록 | `kubectl get apiservice v1beta1.metrics.k8s.io` | `AVAILABLE True` |
| 사용자 조회 | `kubectl top node` | node CPU/memory 출력 |

### 한 줄 요약
> **Helm 설치는 install 명령 하나가 아니라 repo → values → template → install → kubectl 검증까지 이어지는 반복 루프다.**

## 실습 확인 기록

### ① search repo — chart가 보이는지 + 버전 확인
```text
$ helm search repo metrics-server
NAME                           CHART VERSION  APP VERSION  DESCRIPTION
metrics-server/metrics-server  3.13.1         0.8.1        Metrics Server is a scalable, efficient ...
```
- 읽는 포인트:
  - **`metrics-server/metrics-server`** = `repo이름/chart이름`. 이 형태로 보여야 설치 명령에 쓸 수 있음. 안 보이면 `repo add`/`repo update`부터.
  - **CHART VERSION `3.13.1` ≠ APP VERSION `0.8.1`** = 패키지 구조 버전 vs 실제 app 버전. (2교시 설치 출력의 그 값과 동일)

### ② helm template — values가 실제 manifest에 박혔나 (설치 전 검증)
```text
$ helm template metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  -f week4/day1/labs/helm-metrics-server/values.yaml \
  | grep -E "kind: Deployment|kind: APIService|--kubelet-insecure-tls"
kind: Deployment
            - --kubelet-insecure-tls        ← ⭐ 내가 values에 쓴 옵션이 Deployment args에 실제로 렌더됨
kind: APIService
```
- 읽는 포인트:
  - ⭐ **`--kubelet-insecure-tls`가 grep에 잡힘** = values에 쓴 게 **진짜 manifest에 반영**됐다는 증거. "values에 썼으니 됐겠지"를 가정 안 하고 **렌더 결과로 확인**.
  - **`kind: Deployment`** = metrics-server 본체 Pod를 만드는 리소스.
  - **`kind: APIService`** = metrics-server가 **Metrics API를 cluster에 붙이는** 리소스 (aggregation layer). 이게 있어야 `kubectl top`이 동작. (3교시 notes "레이어로 내려가며 확인")
  - `helm template`은 **API Server에 적용 안 함** → cluster를 안 건드리고 미리보기만 한 것.

### ③ get values / get manifest — 적용된 설정·실제 리소스 재현
```text
$ cat week4/day1/labs/helm-metrics-server/values.yaml
args:
  - --kubelet-insecure-tls
  - --kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi

$ helm get values metrics-server -n kube-system
USER-SUPPLIED VALUES:
args:
- --kubelet-insecure-tls
- --kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 64Mi
```
- **repo values ≡ get values → 일치 = drift 없음.** "내가 깐 설정"을 그대로 재현 가능. (다르면 누가 `--set`/다른 파일로 바꾼 것)

```text
$ helm get manifest metrics-server -n kube-system
# (전체 렌더 manifest — 아래 종류가 순서대로 나옴)
# ServiceAccount / ClusterRole×2 / ClusterRoleBinding×2 / RoleBinding / Service / Deployment / APIService
```
- 읽는 포인트:
  - **하나의 release가 8종 리소스를 만듦** → 2교시 "add-on은 리소스 하나가 아니다"의 실물. `kubectl apply`로 일일이 쓰면 이걸 다 손으로 만들어야 함.
  - **RBAC가 큰 비중**(ClusterRole/Binding) → metrics-server가 모든 node/pod의 metric을 읽으려면 권한이 필요. (W4D4 RBAC 미리보기)
  - **APIService `v1beta1.metrics.k8s.io` + `insecureSkipTLSVerify: true`** → Metrics API를 cluster에 붙이는 핵심. `top`이 동작하는 이유.
  - ⚠️ **Deployment args에 `--kubelet-preferred-address-types`가 2번** 보임: chart 기본값(`InternalIP,ExternalIP,Hostname`) + 내 values(`InternalIP,Hostname,ExternalIP`)가 **append**됨. values의 args가 chart 기본 args를 **덮어쓰는 게 아니라 뒤에 붙는** 구조 → 같은 플래그는 보통 **마지막 값이 적용**. (chart마다 args 머지 방식이 달라 `get manifest`로 실제 확인이 중요)

### ④ helm status / kubectl get — 레이어로 내려가며 최종 검증
```text
$ helm list -n kube-system
NAME            NAMESPACE    REVISION  UPDATED                                STATUS    CHART                  APP VERSION
metrics-server  kube-system  4         2026-06-30 17:13:56.257579 +0900 KST   deployed  metrics-server-3.13.1  0.8.1

$ helm status metrics-server -n kube-system
NAME: metrics-server
LAST DEPLOYED: Tue Jun 30 17:13:56 2026
NAMESPACE: kube-system
STATUS: deployed
REVISION: 4
DESCRIPTION: Upgrade complete
RESOURCES:
==> v1/Deployment
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
metrics-server   1/1     1            1           72m

==> v1/Pod(related)
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-5fc94cbbc8-tdltq   1/1     Running   0          62m

==> v1/APIService
NAME                     SERVICE                      AVAILABLE   AGE
v1beta1.metrics.k8s.io   kube-system/metrics-server   True        72m     ← ⭐ Metrics API가 cluster에 붙음

==> v1/ServiceAccount
NAME             AGE
metrics-server   72m

==> v1/ClusterRole
NAME                                      CREATED AT
system:metrics-server-aggregated-reader   2026-06-30T07:15:10Z
system:metrics-server                     2026-06-30T07:15:10Z

==> v1/ClusterRoleBinding
NAME                                   ROLE                                AGE
metrics-server:system:auth-delegator   ClusterRole/system:auth-delegator   72m
system:metrics-server                  ClusterRole/system:metrics-server   72m

==> v1/RoleBinding
NAME                         ROLE                                             AGE
metrics-server-auth-reader   Role/extension-apiserver-authentication-reader   72m

==> v1/Service
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
metrics-server   ClusterIP   10.96.134.156   <none>        443/TCP   72m

$ kubectl -n kube-system get deploy,pod -l app.kubernetes.io/name=metrics-server
NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/metrics-server   1/1     1            1           73m

NAME                                  READY   STATUS    RESTARTS   AGE
pod/metrics-server-5fc94cbbc8-tdltq   1/1     Running   0          63m
```
- 읽는 포인트:
  - **`helm status`가 레이어를 한 번에** 보여줌: release(deployed) + Deployment(1/1) + Pod(Running) + **APIService(AVAILABLE True)** + RBAC + Service. 3교시 "레이어로 내려가며 확인"이 이 한 출력에 다 있음.
  - ⭐ **APIService `AVAILABLE True`** = Metrics API aggregation layer가 정상 연결됨 → 이제 `kubectl top`이 동작할 수 있는 상태. (②의 template에서 본 그 APIService가 실제로 붙은 것)
  - **REVISION 4** = 그동안 upgrade가 4번(기본→values→…) 누적된 현재 활성본.
  - **`deployed`(Helm) + `1/1 Running`(Pod) + `True`(APIService)** 세 층이 다 통과 → "정말 됐다"의 완전한 증거. (Helm 성공만으로 판단 안 함)

### ⑤ rollback — 옛 revision으로 "되돌리는 게 아니라" 새 revision으로 재적용
```text
$ helm history metrics-server -n kube-system
REVISION        UPDATED                         STATUS          CHART                    APP VERSION     DESCRIPTION
1               Tue Jun 30 16:15:10 2026        superseded      metrics-server-3.13.1    0.8.1           Install complete
2               Tue Jun 30 16:22:07 2026        superseded      metrics-server-3.13.1    0.8.1           Upgrade complete
3               Tue Jun 30 16:24:59 2026        superseded      metrics-server-3.13.1    0.8.1           Upgrade complete
4               Tue Jun 30 17:13:56 2026        deployed        metrics-server-3.13.1    0.8.1           Upgrade complete

$ helm rollback metrics-server 1 -n kube-system
Rollback was a success! Happy Helming!

$ helm history metrics-server -n kube-system
REVISION        UPDATED                         STATUS          CHART                    APP VERSION     DESCRIPTION
1               Tue Jun 30 16:15:10 2026        superseded      metrics-server-3.13.1    0.8.1           Install complete
2               Tue Jun 30 16:22:07 2026        superseded      metrics-server-3.13.1    0.8.1           Upgrade complete
3               Tue Jun 30 16:24:59 2026        superseded      metrics-server-3.13.1    0.8.1           Upgrade complete
4               Tue Jun 30 17:13:56 2026        superseded      metrics-server-3.13.1    0.8.1           Upgrade complete
5               Tue Jun 30 17:31:46 2026        deployed        metrics-server-3.13.1    0.8.1           Rollback to 1
```
- 읽는 포인트:
  - ⭐ **`rollback 1`을 했는데 revision 1이 deployed가 되는 게 아니라, 새 revision 5(`Rollback to 1`)가 생기고 그게 deployed.** revision 1 행은 계속 `superseded` → "왜 status가 안 바뀌지?"의 답.
  - **revision 번호는 항상 증가만** (되감기 ❌, 시간순 기록 ⭕). rollback도 앞으로 한 칸 더 간 것. (W3D5 7교시 `rollout undo`가 revision을 새로 만든 것과 동일)
  - ⚠️ **revision 1 = values 없는 최초 설치** → rollback으로 `--kubelet-insecure-tls`가 빠짐. 그 결과:
```text
$ kubectl -n kube-system get pod -l app.kubernetes.io/name=metrics-server
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-5846d89996-kt6rd   0/1     Running   0          3m5s     ← rev5(values 없음) 새 Pod, 인증 실패로 READY 안 됨
metrics-server-5fc94cbbc8-tdltq   1/1     Running   0          69m      ← 기존(values 있던) Pod, 아직 안 죽고 남음

$ helm get values metrics-server -n kube-system
USER-SUPPLIED VALUES:
null                                                                     ← values 비어 있음 = rev1 상태
```
  - **새 Pod `0/1`** = `--kubelet-insecure-tls` 없이 떠서 readinessProbe(`/readyz`) 실패. **기존 Pod `1/1`은 안 죽고 남음** = rolling update 안전장치라 즉시 장애는 아님. (W3D5 7교시 재확인)
  - 교훈: **rollback 대상 revision이 "어떤 values였는지"를 봐야 한다.** 번호만 보고 1로 가면 설정이 유실될 수 있음.

복구 (values 되살리기):
```bash
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  -f week4/day1/labs/helm-metrics-server/values.yaml
```

### ⑥ 복구 후 최종 검증 — kubectl top까지 동작 (사용자 조회 층)
```text
$ helm list -n kube-system
NAME            NAMESPACE       REVISION        UPDATED                                STATUS          CHART                   APP VERSION
metrics-server  kube-system     1               2026-06-30 17:46:22.496073 +0900 KST   deployed        metrics-server-3.13.1   0.8.1

$ kubectl -n kube-system get pod -l app.kubernetes.io/name=metrics-server
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-5fc94cbbc8-2c7lx   1/1     Running   0          88s

$ kubectl get apiservice v1beta1.metrics.k8s.io
NAME                     SERVICE                      AVAILABLE   AGE
v1beta1.metrics.k8s.io   kube-system/metrics-server   True        91s

$ kubectl top node
NAME                            CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
paperclip-week3-control-plane   166m         1%       1394Mi          17%
```
- 읽는 포인트:
  - ⭐ **`kubectl top node`가 실제 수치를 출력** = metrics-server 체인이 끝까지 동작. 1교시·7교시에서 막혔던 `Metrics API not available`이 해소됨.
  - **레이어 4층이 다 통과**: `helm list`(deployed) → `get pod`(1/1 Running) → `apiservice`(AVAILABLE True) → `top node`(수치 출력). 3교시 "레이어로 내려가며 확인"의 완성형.
  - **REVISION이 다시 1** = ⑤에서 망가진 release를 `uninstall` 후 values로 새로 설치(또는 깨끗한 재설치) → revision 카운트가 1부터 리셋. (uninstall은 release 이력까지 지움)
  - **CPU `166m`(1%) / MEM `1394Mi`(17%)** = control-plane node의 실제 사용량. kind라 node가 control-plane 하나뿐이라 한 줄만 나옴.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 공통 설치 루프 7단계는? | repo add → update → values 확인 → upgrade --install → list/status/history → kubectl 확인 → (rollback/uninstall) |
| `helm template`은 무엇? | 설치 전에 values가 반영된 manifest를 렌더링만 해서 미리보기 (API Server 적용 안 함) |
| Chart Version vs App Version? | chart=패키지 구조 버전(3.13.1), app=실제 앱 버전(0.8.1). 서로 다를 수 있음 |
| helm status가 deployed면 끝인가? | 아님. Pod readiness·APIService·`kubectl top`까지 레이어로 확인 |
| `helm get values`와 repo values가 다르면? | 누가 `--set`/다른 파일로 바꿈 = drift. 인수인계 문제. repo values를 기준으로 재현 |
| uninstall 후에도 남는 것은? | PVC/CRD/cluster-scoped resource. chart 정리 정책 확인 |

## notes

### Evidence Note
```markdown
# W4D1S3 Helm install loop
- chart repo:
- release name:
- namespace:
- values file:
- template에서 확인한 리소스:
- status와 pod ready 결과:
```

### `helm template`이 왜 중요한가 — "선언 vs 실제"의 사전 점검
- values에 옵션을 썼다고 chart가 그걸 반영한다는 보장이 없음 (chart가 그 값을 안 읽을 수도).
- `helm template ... | grep --kubelet-insecure-tls`로 **실제 Deployment args에 박혔는지** 설치 전에 확인.
- W3D5의 "200 나와도 배포 성공 아님", 2교시 "deployed ≠ Ready"와 같은 결: **선언을 믿지 말고 렌더/실물로 확인.**

### 레이어로 내려가며 확인 (metrics-server 특화)
```text
helm status (deployed)        ← Helm 층
  → kubectl get pod (1/1)     ← Pod 층
    → kubectl get apiservice v1beta1.metrics.k8s.io (AVAILABLE True)   ← Metrics API 층
      → kubectl top node (사용량 출력)   ← 사용자 조회 층
```
- metrics-server는 **APIService(aggregation layer)**로 Metrics API를 cluster에 붙인다 → `top`이 동작하려면 이 층까지 True여야 함. (2교시 kind 인증 우회가 이 층을 통과시키는 것)

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
