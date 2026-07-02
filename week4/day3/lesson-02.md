# 2교시: kube-prometheus-stack 설치

## 핵심 정리

### kube-prometheus-stack = monitoring 한 묶음 (Prometheus만이 아님)
| 구성요소 | 역할 |
|---|---|
| Prometheus Operator | monitoring CRD(ServiceMonitor 등) reconcile |
| Prometheus | metric scrape·저장·query (retention) |
| Grafana | dashboard |
| Alertmanager | alert routing/silence |
| node-exporter | node metric (DaemonSet) |
| kube-state-metrics | K8s object 상태 metric |

- ⭐ "Prometheus/Grafana 설치"가 아니라 **operator + exporter + rule + alert까지 묶은 stack**. 그래서 CRD가 여러 개 생김.

### 왜 selector 제한을 푸나 (values 핵심)
```yaml
prometheus.prometheusSpec:
  serviceMonitorSelectorNilUsesHelmValues: false   # nil selector = 전부 선택
  podMonitorSelectorNilUsesHelmValues: false
  ruleSelectorNilUsesHelmValues: false
```
- ⭐ 기본값이면 chart label이 붙은 것만 읽음. `false`로 두면 **selector가 비어도(=`{}`) 모든 ServiceMonitor/PodMonitor/PrometheusRule을 읽음** → 수업에서 만든 custom 리소스를 Prometheus가 바로 집어감.

### values에 썼다 ≠ 적용됐다
- ⚠️ Helm values는 "요청"일 뿐. **적용 확인은 두 곳**: Helm은 `helm get values`, Kubernetes는 `kubectl get`으로 실물(Prometheus CR의 `spec.retention` 등) 확인.

### Service 이름을 정확히 (port-forward 대상)
| Service | 포트 | 용도 |
|---|---|---|
| `kube-prometheus-stack-grafana` | 80 | Grafana UI |
| `kube-prometheus-stack-prometheus` | 9090 | Prometheus UI/API |
| `kube-prometheus-stack-alertmanager` | 9093 | Alertmanager |

- ⚠️ port-forward는 **Service 이름이 정확**해야 함. 이름은 `kubectl get svc -n monitoring`로 그 cluster 기준 확인.

### 한 줄 요약
> **kube-prometheus-stack은 Prometheus/Grafana만이 아니라 operator·exporter·rule·alert를 묶은 monitoring stack이다. values는 요청일 뿐 `helm get values`+`kubectl get`으로 실제 적용을 확인한다.**

## 실습 확인 기록

### ① Helm 설치 — repo add/update → upgrade --install
```text
$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
"prometheus-community" has been added to your repositories

$ helm repo update prometheus-community
Update Complete. ⎈Happy Helming!⎈

$ helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace \
    -f week4/day3/labs/kube-prometheus-stack/values.yaml --timeout 10m
NOTES:
kube-prometheus-stack has been installed. Check its status by running:
  kubectl --namespace monitoring get pods -l "release=kube-prometheus-stack"

$ helm list -n monitoring
NAME                    NAMESPACE   REVISION   STATUS     CHART                          APP VERSION
kube-prometheus-stack   monitoring  1          deployed   kube-prometheus-stack-87.5.1   v0.92.1
```
- 읽는 포인트:
  - ⭐ W4D1 helm 루프와 동일: `repo add → update → upgrade --install`. `--create-namespace`로 monitoring ns 자동 생성.
  - ⭐ `STATUS: deployed`는 "Helm이 적용함"일 뿐 → Pod Ready는 아래에서 따로 확인.

### ② 구성요소 6종 Pod Running 확인
```text
$ kubectl -n monitoring get pod
NAME                                                        READY   STATUS    RESTARTS   AGE
alertmanager-kube-prometheus-stack-alertmanager-0           2/2     Running   0          4m47s
kube-prometheus-stack-grafana-85cfffffc-mlj94               3/3     Running   0          4m59s
kube-prometheus-stack-kube-state-metrics-5497db9c5c-6gfjb   1/1     Running   0          4m59s
kube-prometheus-stack-operator-5b5d485c7f-d45mc             1/1     Running   0          4m59s
kube-prometheus-stack-prometheus-node-exporter-7q8fw        1/1     Running   0          4m59s
prometheus-kube-prometheus-stack-prometheus-0              2/2     Running   0          4m47s
```
- 읽는 포인트:
  - ⭐ 6개 구성요소 다 Running: operator·grafana·kube-state-metrics·node-exporter + StatefulSet(prometheus/alertmanager).
  - ⭐ `prometheus-...-0`, `alertmanager-...-0`은 `-0` = **StatefulSet**(저장 필요). grafana/kube-state-metrics는 Deployment.

### ③ CRD와 Service 확인
```text
$ kubectl get crd | grep monitoring.coreos.com
alertmanagerconfigs.monitoring.coreos.com
alertmanagers.monitoring.coreos.com
podmonitors.monitoring.coreos.com
probes.monitoring.coreos.com
prometheusagents.monitoring.coreos.com
prometheuses.monitoring.coreos.com
prometheusrules.monitoring.coreos.com
scrapeconfigs.monitoring.coreos.com
servicemonitors.monitoring.coreos.com
thanosrulers.monitoring.coreos.com

$ kubectl -n monitoring get svc
NAME                                             TYPE        CLUSTER-IP      PORT(S)
kube-prometheus-stack-grafana                    ClusterIP   10.96.197.220   80/TCP
kube-prometheus-stack-prometheus                 ClusterIP   10.96.170.183   9090/TCP,8080/TCP
kube-prometheus-stack-alertmanager               ClusterIP   10.96.11.115    9093/TCP,8080/TCP
kube-prometheus-stack-kube-state-metrics         ClusterIP   10.96.159.50    8080/TCP
kube-prometheus-stack-prometheus-node-exporter   ClusterIP   10.96.82.32     9100/TCP
kube-prometheus-stack-operator                   ClusterIP   10.96.172.134   443/TCP
```
- 읽는 포인트:
  - ⭐ CRD 10종 = operator가 이걸로 Prometheus/Alertmanager/ServiceMonitor 등을 관리. 이게 있어야 custom ServiceMonitor/PrometheusRule이 동작(3·6교시).
  - ⭐ 모두 `ClusterIP` → 외부 접근은 port-forward. Grafana=80, Prometheus=9090, Alertmanager=9093.

### ④ values 실제 적용 + Grafana password 확인
```text
$ kubectl -n monitoring get prometheus kube-prometheus-stack-prometheus \
    -o jsonpath='retention={.spec.retention} smSelector={.spec.serviceMonitorSelector} ruleSelector={.spec.ruleSelector}'
retention=6h smSelector={} ruleSelector={}

$ kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
paperclip-local

# 실제 응답 확인 (in-cluster)
grafana=200        # http://kube-prometheus-stack-grafana/api/health
prometheus=200     # http://kube-prometheus-stack-prometheus:9090/-/ready
```
- 읽는 포인트:
  - ⭐ values의 `retention: 6h`가 **Prometheus CR에 실제 반영됨**(`spec.retention=6h`). selector가 `{}`(빈 값=전부 선택) → `NilUsesHelmValues:false`가 먹은 것.
  - ⚠️ Grafana password가 Secret에서 `base64 -d`로 그대로 나옴 = **base64는 암호화 아님**(W4D1 Secret 감각). 값은 values의 `paperclip-local`.
  - ⭐ Grafana/Prometheus 둘 다 200 → 설치가 "deployed"를 넘어 **실제 서빙**까지 정상.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| kube-prometheus-stack 구성요소? | Operator, Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics |
| Prometheus만 아니라 뭐가 더? | operator(CRD reconcile)+exporter(node/kube-state)+rule+alert |
| selector nil 제한을 왜 풂? | custom ServiceMonitor/PodMonitor/PrometheusRule을 label 없이도 읽게(전부 선택) |
| STATUS deployed면 끝? | 아님. Pod Ready + Service + CRD + 실제 응답까지 확인 |
| values 적용을 어떻게 확인? | helm get values(요청) + kubectl get으로 실물(Prometheus CR retention 등) |
| 왜 -0으로 끝나는 Pod? | prometheus/alertmanager는 StatefulSet(저장 필요) |
| port-forward 대상 Service? | grafana(80)/prometheus(9090)/alertmanager(9093), 이름 정확히 |
| Grafana 로그인? | admin / paperclip-local (Secret base64, 암호화 아님) |

## notes

### Evidence Note
```markdown
# W4D3S2 kube-prometheus-stack
- Helm release: kube-prometheus-stack / monitoring / REVISION 1 / deployed / chart 87.5.1 (operator v0.92.1)
- Prometheus Pod: prometheus-kube-prometheus-stack-prometheus-0 2/2 Running
- Grafana Pod: kube-prometheus-stack-grafana-... 3/3 Running
- Alertmanager Pod: alertmanager-kube-prometheus-stack-alertmanager-0 2/2 Running
- CRD 확인: 10종 monitoring.coreos.com (servicemonitors/podmonitors/prometheusrules 포함)
- 접속: port-forward svc/kube-prometheus-stack-grafana 3000:80 → admin/paperclip-local
       port-forward svc/kube-prometheus-stack-prometheus 9090:9090
- values 적용: retention=6h, serviceMonitor/ruleSelector={}(전부 선택)
- 설치 cluster: kind-paperclip-w4d2 (W4D2 이어서, week4 워크로드 관찰 대상 존재)
```

### port-forward 접속 (다음 교시용)
```bash
# Prometheus
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# Grafana (admin / paperclip-local)
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```
- ⚠️ Service 이름이 다르면 `kubectl -n monitoring get svc`로 먼저 확인. 전용 터미널에 켜두고 사용(W4D2 gateway port-forward와 동일 패턴).

### `--namespace` vs `--create-namespace` (짝)
```text
--namespace monitoring   = 어디에 설치할지 (위치 지정, 존재 여부는 안 봄)
--create-namespace       = 그 namespace 없으면 만들어라
```
- ⚠️ `--namespace`만 주고 ns가 없으면 helm이 거부: `Error: ... namespaces "monitoring" not found`. 그래서 둘이 짝.
- ⭐ 이미 있으면 `--create-namespace`는 무시(항상 붙여도 안전). 대안: `kubectl create ns monitoring` 미리 하고 생략.

### helm `-f` vs kubectl `-f` (글자만 같고 의미 다름)
```text
kubectl apply -f deploy.yaml   -f = 완성된 매니페스트(그대로 적용할 K8s object)
helm install  -f values.yaml   -f = values 파일(차트 기본값을 덮는 설정값, 그 자체는 object 아님)
```
```text
kubectl:  deploy.yaml ──(그대로)──▶ 클러스터
helm:     chart 템플릿 + values.yaml ──(helm 렌더링)──▶ 매니페스트 ──▶ 클러스터
```
- ⭐ helm `-f`(=`--values`)는 "매니페스트"가 아니라 **차트를 커스터마이즈하는 입력값**. 우리 values의 `retention:6h`/`adminPassword`/selector 풀기가 템플릿 빈칸을 채움.
- ⚠️ helm `-f` 안 주면 chart 기본값으로 설치. 주면 그 값이 기본값을 덮어씀.

### deployed ≠ Ready ≠ 서빙 (3단 확인)
```text
helm list → deployed        (Helm이 apply함)
get pod   → Running/Ready    (Pod가 떴나)
curl /-/ready, /api/health → 200  (실제 응답하나)
```
- ⭐ 셋 다 확인해야 "설치 완료". 이번엔 3단계 모두 통과.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| (해당 없음) 설치 1회에 6종 모두 Running | node resource 충분(values로 requests/limits·retention 6h 제한). Pending/OOM 없음 |
| `kubectl top`은 여전히 실패 예상 | kube-prometheus-stack은 metrics.k8s.io API를 안 줌(그건 metrics-server/prometheus-adapter). top과 Prometheus는 별개 |
| values 반영 의심 시 | `kubectl get prometheus ... -o jsonpath=...spec.retention`으로 실물 확인(=6h) |
