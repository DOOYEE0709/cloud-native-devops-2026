# 1교시: Day2 요약 + Kubernetes Observability 기준

## 핵심 정리

### W4D2 질문 → W4D3 질문 (지금 상태 → 시간축)
| W4D2 (traffic) | W4D3 (observability) |
|---|---|
| `/api`가 응답하는가 | `/api` 실패가 **언제부터** 늘었는가 |
| Endpoint가 있는가 | Ready replica가 **시간에 따라** 어떻게 변했나 |
| Pod가 Running인가 | restart가 **증가**했는가 |
| CPU/memory를 지금 볼 수 있나 | 사용량 **추세**가 보이나 |
| controller log에 단서? | target/alert/dashboard로 **반복** 장애를 보나 |

- ⭐ 핵심 전환: **"지금 어떤가" → "시간에 따라 어떻게 변했나".** `kubectl get`은 스냅샷, observability는 추세.

### 네 가지 증거 — 무엇이 잘 보이나
| 증거 | 명령/도구 | 잘 보이는 것 |
|---|---|---|
| Logs | `kubectl logs` | app stdout/stderr |
| Events | `kubectl describe` | scheduling, probe, image pull, kill reason |
| Metrics | Prometheus/Grafana | 시간 흐름·추세·비율 |
| Traces | OpenTelemetry | 요청 경로·span (오늘은 preview만) |

- ⚠️ 하나만으로 결론 금지. metric은 **추세**를 보여주지 원인을 자동으로 말하진 않음.

### `kubectl top` vs Prometheus — 목적이 다름
```text
kubectl top pod        = 지금 CPU/memory (스냅샷, 빠름)   ← metrics-server
Prometheus/Grafana     = 시간 축·추세·비율·상관관계        ← 아래 질문엔 이게 필요
  "한 시간 전부터 CPU가 올랐나 / 어느 Pod가 restart 반복 / 5xx와 readiness 실패가 같은 시점 / node vs namespace 문제"
```

### observability 확인 계층 — 순서가 중요
```text
Prometheus target  → metric 수집 여부 (여기부터 막히면 아래 다 빔)
Grafana dashboard  → 사용량·상태 시각화
PromQL             → 특정 질문을 query로
Alert rule         → 사람이 개입할 조건
Runbook            → 증상별 확인 순서
```
- ⭐ target이 없으면 dashboard가 비고, dashboard가 비면 alert 판단도 어긋남. **아래층부터** 확인.

### metric 이름 prefix 감각 (외우지 말고 접두어로)
| prefix | 대략 의미 |
|---|---|
| `kube_` | kube-state-metrics = K8s object 상태 |
| `container_` | cAdvisor/kubelet = container resource |
| `node_` | node-exporter = node metric |
| `prometheus_` | Prometheus 자체 |
| `nginx_ingress_` | ingress-nginx controller |

### 한 줄 요약
> **observability는 화면을 예쁘게 만드는 일이 아니라 장애 질문을 증거(logs/events/metrics/traces)로 좁히는 방식이다. 그리고 도구를 열기 전에 "내가 어느 cluster/namespace를 보고 있나"부터 맞춰야 한다.**

## 실습 확인 기록

### ① 실습 기준선 — 어느 cluster를 보고 있나 (도구보다 대상 먼저)
```text
$ kubectl config current-context
kind-paperclip-w4d2

$ kind get clusters
paperclip-w4
paperclip-w4d2

$ kubectl get nodes
NAME                           STATUS   ROLES           AGE   VERSION
paperclip-w4d2-control-plane   Ready    control-plane   20h   v1.36.1
```
- 읽는 포인트:
  - ⚠️ kind cluster가 **2개**(`paperclip-w4`=W4D1, `paperclip-w4d2`=W4D2/현재) 존재 → context를 잘못 보면 "Grafana는 열리는데 metric이 빈" 상황이 생김.
  - ⭐ 그래서 observability 수업의 1번은 PromQL이 아니라 **context/node 확인**. 지금 기준은 node `Ready`.

### ② 지금은 metric 인프라가 없다 — 그래서 2교시가 필요
```text
$ kubectl top pod -n week4
error: Metrics API not available

$ kubectl get ns | grep -iE "week4|monitor|observe"
week4                  Active   20h
```
- 읽는 포인트:
  - ⚠️ 현재 cluster(`paperclip-w4d2`)엔 **metrics-server가 없어** `kubectl top`이 실패. W4D1 metrics-server는 다른 cluster(`paperclip-w4`)에 설치했던 것 → cluster가 다르면 도구도 없다.
  - ⚠️ `monitoring`(Prometheus/Grafana), `week4-observe`(장애 시나리오) namespace **아직 없음** → 2교시 `kube-prometheus-stack` 설치로 채운다. observability 확인 계층의 최하단(target)부터 세우는 순서.

### ③ `kubectl get pod` = 스냅샷 (시간축이 없다)
```text
$ kubectl -n week4 get pod
NAME                        READY   STATUS    RESTARTS       AGE
api-7d5f896774-4vzvc        1/1     Running   0              25m
api-7d5f896774-fvlmz        1/1     Running   0              25m
frontend-7d66f6d9cb-k24m5   1/1     Running   1 (118m ago)   20h
frontend-7d66f6d9cb-zcv6s   1/1     Running   1 (118m ago)   20h
postgres-5f945bcf7f-6xfmn   1/1     Running   1 (118m ago)   20h

# 네 가지 증거 중 Events (describe) 예시
$ kubectl -n week4 describe pod -l app=api
Events:
  Type    Reason     Age   From               Message
  Normal  Scheduled  25m   default-scheduler  Successfully assigned week4/api-7d5f896774-4vzvc to paperclip-w4d2-control-plane
  Normal  Pulled     25m   kubelet            Container image "hashicorp/http-echo:1.0" already present ...
  Normal  Created    25m   kubelet            Container created
  Normal  Started    25m   kubelet            Container started
```
- 읽는 포인트:
  - ⭐ `RESTARTS 1`이 보여도 이 출력만으론 "방금인지 어제인지" 추세를 못 봄(스냅샷). 시간축은 Prometheus의 `increase(kube_pod_container_status_restarts_total[10m])` 같은 query로 봐야 함.
  - ⭐ `describe`의 Events = 네 가지 증거 중 "Events"(scheduling/probe/kill reason). 지금은 정상이라 Normal뿐. (api Pod가 25m로 새것인 건 W4D2 rollout undo로 교체됐기 때문.)

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| W4D2와 W4D3 질문의 차이? | W4D2="지금 응답하나", W4D3="언제부터/얼마나 자주/추세가 어떤가"(시간축) |
| 네 가지 증거는? | Logs(kubectl logs), Events(describe), Metrics(Prometheus/Grafana), Traces(OTel) |
| kubectl top과 Prometheus 차이? | top=지금 스냅샷(빠름), Prometheus=시간축·추세·상관관계 |
| observability 수업의 1번 확인? | PromQL 아니라 "어느 cluster/namespace 보고 있나"(context/node) |
| 지금 kubectl top이 왜 실패? | 이 cluster(paperclip-w4d2)에 metrics-server 없음. W4D1 것은 paperclip-w4에 있었음 |
| 확인 계층 순서? | target→dashboard→PromQL→alert→runbook. target 없으면 다 빔 |
| metric 이름 어떻게 접근? | prefix 감각(kube_/container_/node_/prometheus_/nginx_ingress_)으로 |
| kubectl get pod의 한계? | 스냅샷이라 RESTARTS가 언제 났는지 추세를 못 봄 |

## notes

### Evidence Note
```markdown
# W4D3S1 Observability baseline
- logs로 볼 것: app 내부 오류(예: api 5xx 메시지)
- events로 볼 것: readiness 실패, OOMKilled, scheduling, image pull
- metrics로 볼 것: restart 증가량, namespace/pod CPU·memory 추세, up(target)
- 오늘 가장 보고 싶은 dashboard: namespace별 CPU/memory + Pod restart 추세
- W4D2 장애 중 metric으로 보고 싶은 것: /api 실패율과 readiness 실패가 같은 시점인지
- baseline 사실: context=kind-paperclip-w4d2, cluster 2개 존재, 이 cluster엔 metrics-server/monitoring 없음(2교시에 설치)
```

### 도구보다 관찰 대상 먼저 (오늘 실측으로 배운 것)
```text
cluster 2개(paperclip-w4, paperclip-w4d2) 존재
  → context가 w4d2인데 top이 "Metrics API not available"
  → 도구(top/Grafana)가 문제가 아니라 "그 cluster엔 그 인프라가 없다"
결론: 관찰이 이상하면 query 전에 context/namespace부터.
```

### 기본 PromQL (2교시 이후 target 생기면 사용)
```promql
up                                                          # target 살아있나
sum by (namespace) (container_memory_working_set_bytes{container!="", image!=""})
sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{container!="", image!=""}[5m]))
increase(kube_pod_container_status_restarts_total[10m])     # 최근 10분 restart 증가
```
- ⚠️ 각 query는 정답이 아니라 출발점. label(namespace/pod/container)로 좁혀가며 찾음. 지금은 Prometheus가 없어 실행 대상이 아직 없음.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| `kubectl top pod` → `Metrics API not available` | 이 cluster(paperclip-w4d2)에 metrics-server 미설치. W4D1 metrics-server는 다른 cluster(paperclip-w4)에 있었음 → cluster 확인이 먼저 |
| monitoring/week4-observe namespace 없음 | 아직 정상. 2교시 kube-prometheus-stack 설치 + 장애 시나리오 배포로 생김 |
| RESTARTS 값만으론 원인 판단 불가 | get pod은 스냅샷. 추세는 Prometheus increase()로 봐야 함 |
