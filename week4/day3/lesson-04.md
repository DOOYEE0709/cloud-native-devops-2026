# 4교시: Grafana Dashboard 확인

## 핵심 정리

### Grafana 접속
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000  →  admin / paperclip-local
```

### dashboard 읽는 순서 — 전체 → namespace → pod → 원인
| 순서 | 질문 | dashboard |
|---|---|---|
| 1 | node 전체가 힘든가 | Node Exporter |
| 2 | 어떤 namespace가 쓰는가 | Compute Resources / Namespace |
| 3 | 어떤 Pod가 쓰는가 | Compute Resources / Pod |
| 4 | restart가 늘었는가 | Workload/Pod dashboard |
| 5 | target이 정상인가 | Prometheus Targets |
- ⭐ 처음부터 모든 panel 보면 길 잃음. **넓게 → 좁게**로 범위를 줄임. Grafana 상단 variable도 `All ns → week4 → api → api-xxxxx` 순으로 좁힘.

### kubectl(현재) ↔ Grafana(시간축)
| kubectl | Grafana |
|---|---|
| 현재 CPU/memory | 시간별 CPU/memory |
| 현재 RESTARTS | restart 증가 **시점** |
| 현재 Pod READY | ready replica 추세 |
| describe event | metric 변화와 함께 원인 추적 |
- ⭐ 같은 정보를 Grafana는 **시간 축**으로 확장 → 장애의 시작점·범위를 봄.

### dashboard ≠ alert
```text
dashboard → 사람이 들어가서 관찰
alert     → 조건 맞으면 사람에게 알림
```
- ⚠️ dashboard의 모든 spike를 alert로 만들면 안 됨(피로). 지속시간·사용자 영향으로 판단.

### panel 해석 주의
- ⚠️ 순간 spike만으로 장애 단정 X (지속시간 확인). CPU만 X (memory/restart/readiness 같이). node 전체만 X (ns/pod로 좁힘). dashboard만 X (logs/events로 원인).

### 한 줄 요약
> **Grafana dashboard는 kubectl의 현재 상태를 시간 축으로 확장해 장애의 시작점과 범위를 찾게 해준다. 전체→namespace→pod→원인 순으로 좁히고, panel 하나로 단정하지 않는다.**

## 실습 확인 기록

> dashboard panel이 그리는 값을 PromQL로 직접 조회해 확인(브라우저 Grafana는 같은 값을 시간 축 그래프로 보여줌). Prometheus API: `http://kube-prometheus-stack-prometheus:9090/api/v1/query`.

### ① namespace별 CPU/memory (Compute Resources / Namespace)
```text
# memory: sum by (namespace) (container_memory_working_set_bytes{container!="",image!=""})
namespace              memory
kube-system            1530.6 MiB
monitoring              877.9 MiB
envoy-gateway-system    195.4 MiB
week4                   106.2 MiB
local-path-storage       18.9 MiB

# cpu: sum by (namespace) (rate(container_cpu_usage_seconds_total{container!="",image!=""}[5m]))
namespace              cpu
kube-system            99m  (0.099 cores)
monitoring             34m
envoy-gateway-system    9m
week4                   2m
local-path-storage      0m
```
- 읽는 포인트:
  - ⚠️ **monitoring이 memory 2위(877 MiB)** = 관찰 스택 자체가 무겁다(2교시 "kube-prometheus-stack은 가벼운 chart가 아니다"가 수치로 확인). "관찰 인프라도 자원을 쓴다".
  - ⭐ 실습 앱 week4는 CPU 2m/mem 106 MiB로 아주 가벼움(http-echo/nginx/postgres idle). 부하는 kube-system(control-plane)이 대부분.

### ② memory top pod (Compute Resources / Pod)
```text
# topk(6, sum by (namespace,pod) (container_memory_working_set_bytes{container!="",image!=""}))
namespace              pod                                             memory
kube-system            kube-apiserver-...-control-plane                952.1 MiB
monitoring             kube-prometheus-stack-grafana-...               388.2 MiB
monitoring             prometheus-kube-prometheus-stack-prometheus-0   352.6 MiB
kube-system            etcd-...-control-plane                          152.6 MiB
kube-system            kube-controller-manager-...-control-plane       145.4 MiB
envoy-gateway-system   envoy-week4-paperclip-gateway-...               131.3 MiB
```
- 읽는 포인트:
  - ⭐ namespace(①)를 pod 단위(②)로 좁힘 = dashboard 순서 그대로. monitoring 877 MiB의 정체 = **grafana(388)+prometheus(352)** 두 Pod.
  - ⭐ 단일 최대는 **kube-apiserver 952 MiB**(control-plane). "어느 namespace"→"어느 pod"로 내려가야 진짜 소비자가 보임.

### ③ week4 ready replica + restart 추세 (Workload dashboard)
```text
# kube_deployment_status_replicas_ready{namespace="week4"}
deployment   ready
api          2
frontend     2
postgres     1

# sum by (namespace,pod) (increase(kube_pod_container_status_restarts_total[10m]))
→ 0이 아닌 것 없음 (최근 10분 restart 증가 전부 0)
```
- 읽는 포인트:
  - ⭐ ready replica가 desired와 일치(api 2/2, frontend 2/2, postgres 1/1) = 배포 정상. `kubectl get deploy`의 READY를 **시간축 metric**으로 본 것.
  - ⭐ restart 증가 0 = 지금은 장애 없음(정상 baseline). CrashLoop 시나리오(5교시) 배포하면 이 값이 튀는 걸 같은 query로 확인하게 됨.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| dashboard 읽는 순서? | 전체(node)→namespace→pod→원인. 넓게서 좁게 |
| kubectl과 Grafana 차이? | kubectl=현재 스냅샷, Grafana=같은 값을 시간 축으로 |
| dashboard와 alert 차이? | dashboard=사람이 봐야 함, alert=조건 맞으면 알려줌 |
| memory를 제일 많이 쓴 namespace? | kube-system(1530MiB), 그 다음 monitoring(877MiB) |
| monitoring이 무거운 이유? | grafana(388)+prometheus(352) = 관찰 스택 자체가 무거움 |
| 단일 최대 memory pod? | kube-apiserver(952MiB, control-plane) |
| week4 배포는 정상? | api2/frontend2/postgres1 ready = desired와 일치 |
| restart 추세는? | 최근 10분 증가 0 (장애 없음, 5교시에서 튀는 것 확인 예정) |
| panel 하나로 단정하면? | 위험. spike 지속시간, memory/restart/readiness 같이, logs/events로 원인 |

## notes

### Evidence Note
```markdown
# W4D3S4 Grafana
- 접속 URL: http://localhost:3000 (port-forward svc/kube-prometheus-stack-grafana 3000:80), admin/paperclip-local
- 확인한 dashboard: Compute Resources/Namespace, Compute Resources/Pod, Workload
- CPU가 높은 namespace: kube-system(99m) > monitoring(34m) > envoy(9m) > week4(2m)
- memory가 높은 namespace/pod: kube-system 1530MiB(apiserver 952), monitoring 877(grafana388+prometheus352)
- restart가 보인 Pod: 없음(최근 10분 증가 0) — 정상 baseline
- kubectl과 비교: kubectl top(현재) ↔ Grafana(시간축), get deploy READY ↔ kube_deployment_status_replicas_ready
- dashboard time range: Last 30m~1h 권장(rollout/장애 전후 비교)
- screenshot에 포함할 것: time range + namespace/pod filter + panel title + spike구간 + 같은 시점 kubectl evidence
```

### dashboard panel = PromQL (직접 조회하면 같은 값)
```promql
# namespace memory
sum by (namespace) (container_memory_working_set_bytes{container!="", image!=""})
# pod CPU (label 좁히기: namespace 지정 + legend {{pod}})
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="week4-observe", container!="", image!=""}[2m]))
# restart 증가
increase(kube_pod_container_status_restarts_total[10m])
# ready replica
kube_deployment_status_replicas_ready
```
- ⭐ legend가 지저분하면 `sum by (pod)` / `sum by (pod, container)`로 label 줄이고 legend format `{{pod}}` 사용. `instance`/`endpoint`는 운영 label이라 처음엔 noise.

### time range 감각
| 범위 | 용도 |
|---|---|
| Last 5m | 방금 재현한 장애 |
| Last 30m | rollout 전후 비교 |
| Last 1h | 수업 전체 흐름 |
| Last 6h | retention(6h) 안에서 넓게 |
- ⚠️ 장애가 안 보이면 **time range부터** 의심(너무 넓/좁). retention 6h 넘으면 데이터 없음.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| dashboard가 비어 보임 | ①target UP(3교시) ②time range(retention 6h 내) ③namespace/pod variable filter 순으로 확인 |
| monitoring이 자원 많이 씀 | 비정상 아님. 관찰 스택(grafana+prometheus)이 원래 무거움 → values로 retention/limit 통제 |
| restart panel이 0 | 정상 baseline. 장애 시나리오(5교시) 배포 후 같은 query로 튀는지 확인 |
