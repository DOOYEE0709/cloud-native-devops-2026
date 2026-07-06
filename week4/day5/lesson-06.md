# 6교시: Istio/Kiali Helm 설치

```bash
# 실습 환경 변수
export ISTIONS=istio-system
export INGNS=istio-ingress
export KIALIOPNS=kiali-operator
export LAB=cloud-native-devops-2026/week4/day5/labs/istio
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① `helm repo add istio https://istio-release.storage.googleapis.com/charts` + `helm repo add kiali https://kiali.org/helm-charts` + `helm repo update istio kiali` | 두 repo 추가, `Update Complete` |
| ② `helm upgrade --install istio-base istio/base --namespace $ISTIONS --create-namespace -f $LAB/base-values.yaml` | `STATUS: deployed`, `base-1.30.2` (CRD/기본 리소스) |
| ③ `helm upgrade --install istiod istio/istiod --namespace $ISTIONS -f $LAB/istiod-values.yaml --wait --timeout 300s` | `STATUS: deployed`, `istiod-1.30.2` (control plane) |
| ④ `helm upgrade --install istio-ingress istio/gateway --namespace $INGNS --create-namespace -f $LAB/gateway-values.yaml --wait` | `STATUS: deployed`, `gateway-1.30.2` |
| ⑤ `helm upgrade --install kiali-operator kiali/kiali-operator --namespace $KIALIOPNS --create-namespace -f $LAB/kiali-values.yaml --wait` | `STATUS: deployed`, `kiali-operator-2.28.0` |
| ⑥ `helm list -A \| grep -iE "istio\|kiali"` | istio-base / istiod / istio-ingress / kiali-operator 4개 release `deployed` |
| ⑦ `kubectl -n $ISTIONS get pods,svc` | `istiod ... 1/1 Running`, `svc/istiod 15010/15012/443/15014`, `kiali ... 1/1 Running`, `svc/kiali 20001/9090` |
| ⑧ `kubectl -n $INGNS get pods,svc` | `istio-ingress ... 1/1 Running`, `svc/istio-ingress ClusterIP 15021/80/443` (kind라 ClusterIP) |
| ⑨ `kubectl -n $KIALIOPNS get pods` | `kiali-operator ... 1/1 Running` |
| ⑩ `kubectl -n $ISTIONS get kiali` | `kiali` CR 존재 (operator가 생성) |
| ⑪ `kubectl -n $ISTIONS wait --for=condition=Ready pod -l app=kiali --timeout=120s` | `condition met` → kiali `1/1 Running` (처음엔 0/1이라 대기 필요) |
| ⑫ `kubectl -n $ISTIONS get kiali kiali -o jsonpath='{.spec.external_services.prometheus.url}'` | `http://kube-prometheus-stack-prometheus.monitoring:9090` (W4D3 Prometheus에 연결) |
| ⑬ `kubectl -n monitoring get svc kube-prometheus-stack-prometheus` | `9090/TCP` — Kiali가 쓸 Prometheus 도달 가능 |
| ⑭ UI 접속용 `kubectl -n $ISTIONS port-forward svc/kiali 20001:20001` | `http://localhost:20001` |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 설치를 왜 Helm으로 통일하나? | 재현성(values 파일), 비교 가능(chart/version/values evidence), release 단위 삭제, 운영 친화 |
| istio 설치 3단계 역할은? | base=CRD/기본 리소스, istiod=control plane, gateway=ingress/egress gateway |
| gateway를 왜 ClusterIP로? | local kind에 LoadBalancer가 없어도 설치 흐름 확인 위해 |
| `accessLogFile: /dev/stdout`가 하는 일은? | istio-proxy container log에서 요청 흔적을 볼 수 있게 함 |
| Kiali는 무엇을 읽어 graph를 그리나? | Prometheus metric (`kube-prometheus-stack-prometheus.monitoring:9090`) |
| Kiali graph가 비면 항상 설치 실패인가? | 아니오. traffic이 아직 없거나 Prometheus scrape이 안 쌓였을 수도 있음 |

## notes

### 설치 원칙 — Helm으로 통일
| 이유 | 설명 |
|---|---|
| 재현성 | values 파일로 설정을 남길 수 있음 |
| 비교 가능 | chart/version/values를 evidence로 남길 수 있음 |
| 삭제 용이 | release 단위로 uninstall 가능 |
| 운영 친화 | 현장에서도 Helm 기반 설치가 흔함 |

`kubectl apply -f <인터넷 URL>`은 빠르지만 어떤 설정이 들어갔는지 추적이 어렵다.

### Istio 설치 순서
```text
istio/base    → CRD와 기본 리소스
istio/istiod  → control plane
istio/gateway → ingress/egress gateway
```

### values 핵심
```yaml
# base-values.yaml
defaultRevision: default

# istiod-values.yaml
meshConfig:
  accessLogFile: /dev/stdout   # istio-proxy log로 요청 관찰
pilot:
  autoscaleEnabled: false

# gateway-values.yaml
service:
  type: ClusterIP              # kind에 LB 없으므로

# kiali-values.yaml (operator가 CR로 Kiali 배포)
cr:
  spec:
    auth:
      strategy: anonymous
    external_services:
      prometheus:
        url: http://kube-prometheus-stack-prometheus.monitoring:9090
```

### Kiali 설치 구조
Kiali는 **operator**를 Helm으로 설치하면, operator가 `Kiali` CR을 읽어 실제 Kiali Deployment를 `istio-system`에 만든다.

```text
helm install kiali-operator → Kiali CR(create:true) → operator가 kiali Deployment 생성
```
그래서 helm 설치 직후 kiali Pod는 잠깐 `0/1`이다가 Ready(`1/1`)가 된다.

### Prometheus 연결 주의
W4D3 kube-prometheus-stack이 있으면 Service 이름은 보통 `kube-prometheus-stack-prometheus.monitoring:9090`. Kiali가 graph를 못 그리면 먼저 이 연결을 확인한다.

```bash
kubectl -n monitoring get svc | grep prometheus
kubectl -n istio-system describe kiali kiali
```

Graph가 비어 있는 게 항상 설치 실패는 아니다 — traffic이 없거나 scrape이 덜 쌓였을 수 있다(7교시에서 traffic 생성 후 확인).

### Resource 주의
Istio/Kiali는 local cluster에서 무겁다.

| 증상 | 점검 |
|---|---|
| Pod Pending | Docker Desktop/WSL CPU/Memory |
| istiod CrashLoopBackOff | values, image pull, resource |
| Kiali graph empty | Prometheus, traffic, namespace 선택 |
| UI 접속 안 됨 | port-forward namespace/service |

### 한 줄 요약
Istio/Kiali 설치는 **Helm release, Pod 상태, Prometheus 연결, UI 접속**까지 함께 확인해야 한다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| 설치 직후 `kubectl -n istio-system get pod`에서 kiali가 `0/1 Running` | operator가 CR 보고 Deployment 만든 직후라 기동 중. `wait --for=condition=Ready pod -l app=kiali`로 대기하면 `1/1`이 됨 |
