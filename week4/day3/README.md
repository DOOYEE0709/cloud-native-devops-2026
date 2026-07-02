# Week 4 Day 3 — Observability: Prometheus·Grafana로 장애를 증거로 좁히기

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Day2 요약 + Observability 기준 | "지금 어떤가"→"시간에 따라 어떻게 변했나". logs/events/metrics/traces 구분. 도구보다 관찰 대상(context/ns) 먼저 |
| 2교시 | kube-prometheus-stack 설치 | Prometheus/Grafana/Alertmanager+operator+exporter+rule을 Helm으로. deployed≠Ready≠서빙, values는 `helm get values`+`kubectl get`으로 확인 |
| 3교시 | Prometheus Target 확인 | `up=1/0/series없음` 구분. ServiceMonitor가 target 생성. kind control-plane DOWN(127.0.0.1 바인딩)은 설치 실패 아님 |
| 4교시 | Grafana Dashboard 확인 | 전체→namespace→pod→원인 순. kubectl(현재)↔Grafana(시간축). panel 하나로 단정 금지 |
| 5교시 | 장애와 Metric 연결 | CrashLoop/readiness/CPU를 metric 시그니처로 구분. restart만 보면 readiness 놓침. 원인은 logs(NPE)/describe(OOM) |
| 6교시 | Alert Preview | inactive/pending/firing, `for`로 spike 거름. threshold 낮으면 alert fatigue(양치기 소년). restart 기반은 readiness 못 잡음 |
| 7교시 | 관찰 Runbook 작성 | 증상→metric→kubectl evidence→조치→전달. 증상별 볼 metric이 다름을 runbook이 강제. 개발팀엔 증상+시간+metric+evidence+조치 |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-07.md` | 교시별 핵심 정리·실습 확인 기록·확인 질문·notes·Blocker Log |
| `labs/kube-prometheus-stack/values.yaml` | 설치용 Helm values (retention 6h, selectorNil 해제, resource 제한, Grafana admin) |
| `labs/observability-scenarios/` | 장애 재현 시나리오 + PrometheusRule |
| `assets/lesson-03/` | Prometheus `up` 타깃 스크린샷(up.png, up-monitoring.png) |

### labs/observability-scenarios 구성

| 파일 | 역할 |
|---|---|
| `namespace.yaml` | `week4-observe` 격리 namespace |
| `crashloop-demo.yaml` | `exit 1` 반복 → CrashLoopBackOff (restart 증가) |
| `readiness-bad-demo.yaml` | nginx readinessProbe `/not-ready`(404) → 안 죽고 READY 0/1 |
| `cpu-pressure-demo.yaml` | `while true` → CPU limit까지(throttling) |
| `prometheus-rule-preview.yaml` | restart 증가 alert `Week4ObservePodRestarting`(for 1m) |

## 실습 환경

kind cluster `paperclip-w4d2`(node `paperclip-w4d2-control-plane`), W4D2에 이어서 진행(week4 워크로드를 관찰 대상으로 재사용).

- **monitoring** namespace: `kube-prometheus-stack` (Helm chart 87.5.1 / operator v0.92.1). CNI는 kindnet `v20260528`.
- **week4-observe** namespace: 장애 재현 시나리오 3종 + PrometheusRule.
- UI 접근은 ClusterIP라 port-forward:
  ```bash
  kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090    # /targets, /alerts
  kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80         # admin / paperclip-local
  kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093  # silence
  ```
- ⚠️ `kubectl top`은 이 cluster에선 실패(metrics-server 없음). Prometheus와 `kubectl top`은 별개 경로.

## 핵심 한 줄

observability는 화면을 예쁘게 만드는 게 아니라 **장애 질문을 증거로 좁히는 방식**이다. metric은 "언제·얼마나"(시간·범위)를, logs/events는 "왜"(원인)를 보여준다. 증상이 같아 보여도 metric 시그니처(restart↑ / ready=0 / CPU rate↑)로 분기하고, alert는 threshold를 낮추면 양치기 소년이 되므로 사람이 할 행동·runbook과 연결한다.

## 다음 연결

W4D3에서 세운 target·dashboard·alert·runbook은 W4D4 **RBAC/Kyverno**로 이어진다. "누가 monitoring namespace를 수정하나(RBAC)", "누구에게 PrometheusRule 생성 권한을 주나(Role/RoleBinding)", "위험한 manifest를 배포 전에 막을 수 있나(Kyverno admission)", "policy 위반도 dashboard/alert로 보나(observability+security)"가 다음 질문이다. NetworkPolicy(W4D2)는 Cilium/Hubble(CNI 계층)로도 확장된다.

## cleanup

실습 후 정리(다음 수업 방해 방지):
```bash
kubectl delete namespace week4-observe          # 장애 시나리오 제거
helm uninstall kube-prometheus-stack -n monitoring
kubectl delete namespace monitoring             # stack 제거(유지하려면 생략)
```
유지 시 `helm list -A`와 `kubectl get ns` 결과를 기록한다.
