# 7교시: 관찰 Runbook 작성

## 핵심 정리

### Runbook = 장애 중에 새로 생각하지 않으려고 미리 쓰는 확인 순서
```text
증상 → 영향 범위 → metric → kubectl evidence → dashboard → 임시 조치 → 개발팀 전달
```
- ⭐ 장애 순간엔 판단력이 떨어짐. "다음에 뭘 볼지"를 평소에 문서로 정해둠.

### 증상별 runbook (오늘 재현한 것 기준)
| 증상 | PromQL/Dashboard | kubectl |
|---|---|---|
| 503 증가 | ingress 5xx, endpoint ready 감소 | `get svc,endpoints` |
| Pod restart 증가 | restart total/increase | `logs --previous`, `describe pod` |
| CPU 압박 | CPU rate, throttling | `top pod`, resources |
| memory 증가 | working set, OOMKilled | `describe pod`, events |
| target down | `up == 0`, Targets UI | ServiceMonitor, Service, Endpoint |
| rollout 지연 | ready replica, restart | `rollout status`, `get rs,pod` |
| alert firing | `ALERTS{alertname=...}` | `get prometheusrule`, 관련 Pod `describe` |

### 개발팀에 전달할 때 빼면 안 되는 것
- ⚠️ "느려요"만 보내면 부족. **시간 + 영향 + 최근 변경 + metric + event/log + 조치**를 함께 → 개발팀이 재현 없이 원인을 좁힘.

### 한 줄 요약
> **runbook은 장애 중에 새로 생각하지 않기 위해 평소에 작성하는 확인 순서다. 증상마다 볼 metric·kubectl·dashboard를 미리 연결하고, 개발팀에는 증상+시간+metric+evidence+조치를 함께 전달한다.**

## 실습 확인 기록

> 오늘(W4D3) 실제 재현한 장애 4종을 runbook 항목으로 정리. 값은 이 세션에서 실측한 것.

### ① 종합 검증 runbook 표 (오늘 증거)
```text
증상                 metric(실측)                     kubectl evidence                     판단
CrashLoopBackOff     restart total 27, alert firing   logs --previous, describe pod        container 반복 종료
readiness 404        ready(true)=0, restart=0         describe: probe failed 404           app route/probe mismatch
CPU loop             CPU rate 92m (limit 100m)        top pod, deploy command(while true)  지속 부하(throttling)
scheduler target down up{job=kube-scheduler}=0        ServiceMonitor/Endpoint, target error kind localhost 바인딩
```
- 읽는 포인트:
  - ⭐ 같은 "죽었다/느리다" 증상도 **metric 시그니처가 다름** → runbook이 그 분기를 미리 적어둔 것.
  - ⚠️ readiness는 restart=0이라 restart runbook만 따라가면 놓침 → **증상별로 볼 metric이 다르다**를 표가 강제.

### ② 예시 runbook — restart 증가 (crashloop, 오늘 값)
```markdown
## Symptom
- week4-observe crashloop-demo restart 증가 (Grafana restart panel)

## Metrics
- kube_pod_container_status_restarts_total{...crashloop...} = 27 (total)
- increase(...[5m]) = 1.11  ← backoff로 window 좁으면 0일 수 있음, total도 확인
- ALERTS{alertname="Week4ObservePodRestarting"} = firing (value 1.11)

## Kubernetes evidence
- kubectl -n week4-observe get pod  → 0/1 CrashLoopBackOff / Error
- kubectl -n week4-observe logs deploy/crashloop-demo --previous  → "intentional restart for observability"
- kubectl -n week4-observe describe pod -l app=crashloop-demo  → Warning BackOff "Back-off restarting failed container"

## Action
- 배포 직후 정상 restart인지 반복 crash인지 구분 (여기선 반복 crash)
- Last State/exit code/최근 image tag 확인 → 원인 개발팀 전달
```

### ③ 예시 runbook — readiness rollout 정지 (오늘 값)
```markdown
## Symptom
- readiness-bad-demo가 Running인데 READY 0/1로 남음(트래픽 못 받음)

## Metrics
- kube_pod_status_ready{namespace="week4-observe", condition="true"} = 0
- restart는 0 (증가 안 함) ← restart metric만 보면 놓침

## Kubernetes evidence
- kubectl -n week4-observe describe pod -l app=readiness-bad-demo
  → Warning Unhealthy "Readiness probe failed: HTTP probe failed with statuscode: 404"
- kubectl -n week4-observe get endpoints  → 새 Pod endpoint에서 빠짐

## Action
- readiness path(/not-ready)와 app route 확인
- 이전 ReplicaSet이 traffic 유지 중인지 endpoint 확인 → 수정 또는 rollback
```

### ④ 개발팀 전달 문장 (오늘 재현으로 작성)
```markdown
[증상] week4-observe crashloop-demo가 반복 재시작(CrashLoopBackOff)
[시간] 실습 배포 후 ~약 2시간 지속 (restart 27회)
[영향] week4-observe namespace (실습용 격리, 사용자 영향 없음)
[metric] restart total 27, increase[30m]=8, alert Week4ObservePodRestarting firing
[evidence] logs --previous: "intentional restart", event: Back-off restarting failed container
[원인추정] container command가 sleep 5; exit 1 (의도적 종료)
[요청] 정상 종료 로직 또는 재시작 정책 검토
```
- 읽는 포인트:
  - ⭐ metric 이름만 X. **증상+시간+영향+metric+evidence+원인추정+요청**을 묶어야 재현 없이 원인 좁힘.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| runbook이 필요한 이유? | 장애 중엔 판단력↓. "다음에 뭘 볼지"를 평소에 정리 |
| runbook 흐름? | 증상→영향범위→metric→kubectl evidence→dashboard→임시조치→개발팀 전달 |
| restart 증가 runbook 핵심 명령? | logs --previous, describe pod(Last State/Events) |
| readiness 정지 runbook 포인트? | ready=0이지만 restart=0 → describe event(probe 404), endpoint 확인 |
| CPU 압박 판단? | CPU rate가 limit까지(throttling). 죽기보다 느려짐 |
| target down runbook? | up==0 확인 → target error/ServiceMonitor/Endpoint |
| 개발팀에 뭘 전달? | 증상+시간+영향+최근변경+metric+event/log+조치 |
| 하나의 runbook으로 다 되나? | 아님. 증상마다 볼 metric이 달라 분기 필요(restart≠ready) |

## notes

### Runbook template
```markdown
# Incident note
## Symptom       - URL/API / status·error / start time
## Metrics       - dashboard / PromQL / value·change
## Kubernetes evidence - namespace / svc·endpoint / pod READY·restart / events·logs
## Action        - rollback·restart·scale / result
## Handoff       - suspected cause / app owner request / evidence links
```

### 개발팀 전달 필수 항목 (빼면 안 됨)
| 정보 | 예시 |
|---|---|
| 시간 | 10:32~10:38 KST |
| 영향 | `/api` 503 |
| 최근 변경 | deploy/api revision 4 |
| metric | ready replica 2 → 0 |
| event | readiness probe 404 |
| log | `/ready` route not found |
| 조치 | rollback revision 3 |
- ⚠️ 이 정도 있어야 개발팀이 **재현 없이** 원인을 좁힘. "느려요"는 부족.

### W4D1~W4D3가 runbook으로 합쳐짐
| Day | runbook 기준 |
|---|---|
| W4D1 | readiness, resources(requests/limits), metrics-server |
| W4D2 | Gateway/Ingress, Service, Endpoint, NetworkPolicy |
| W4D3 | Prometheus target, dashboard, alert, runbook |
- ⭐ 3일치가 "증상→증거→조치"라는 하나의 확인 순서로 수렴. observability는 도구가 아니라 이 순서를 갖추는 것.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| 증상이 같아 보임(둘 다 "Pod 문제") | metric 시그니처로 분기: crashloop=restart↑, readiness=ready0/restart0, cpu=rate↑ → runbook이 분기를 강제 |
| restart runbook만 따르면 readiness 놓침 | readiness는 restart=0 → ready metric + describe event(404) 경로를 runbook에 별도로 둠 |
| 개발팀이 "재현 안 된다"고 함 | 전달에 시간·최근변경·metric·event·조치가 빠졌을 때. 필수 항목 표대로 채워 전달 |
