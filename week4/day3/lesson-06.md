# 6교시: Alert Preview

## 핵심 정리

### Alert 흐름 — 조건이 "유지"돼야 사람을 부른다
```text
PromQL 조건 만족 → for 시간 유지 → pending → firing → Alertmanager(group/route) → silence 또는 알림
```
| 상태 | 의미 |
|---|---|
| inactive | 조건 불만족 |
| pending | 조건 만족 중이지만 `for` 대기 |
| firing | 조건이 `for`만큼 유지되어 발생 |

- ⭐ alert = "metric이 있다"가 아니라 **"사람이 개입해야 할 조건"** 을 정의하는 것.

### `for`가 pending을 만든다 (순간 spike 거르기)
```yaml
expr: increase(kube_pod_container_status_restarts_total{namespace="week4-observe"}[5m]) > 0
for: 1m        # 조건이 1분 유지돼야 firing
```
- ⭐ `for` 없으면 순간 spike에도 바로 firing. 배포 중 restart 1회는 정상일 수 있어 `for`로 거름.

### ⚠️ threshold 너무 낮으면 = 양치기 소년 (alert fatigue)
- ⭐ 임계값을 너무 낮게 잡으면 alert가 쏟아짐 → 사람이 **꺼버리거나 무시** → **진짜 장애 때 못 잡음**. alert는 많을수록이 아니라 **적절할수록** 좋다.

| 나쁜 alert | 문제 | 더 나은 조건 |
|---|---|---|
| CPU 50% 1분 | 너무 흔함 | 10분 이상 지속 |
| Pod restart 1회 | 배포 중 정상일 수도 | 사용자 영향 metric과 결합 |
| target down 즉시 | 일시 재시작에도 울림 | severity 구분 + runbook link |

### Alertmanager = 보내는 게 아니라 다스리는 것
| 기능 | 의미 |
|---|---|
| grouping | 비슷한 alert 묶음 |
| routing | severity/team/service로 전달 |
| inhibition | 상위 장애 시 하위 alert 억제 |
| silence | 아는 작업/테스트 중 일정 시간 숨김 |
- ⚠️ silence는 **장애를 고치는 게 아니라** 이미 아는 상황의 알림을 줄이는 것.

### 좋은 alert 문장 = 다음 행동이 있다
- 나쁨: `PodRestarting`
- 좋음: `week4-observe에서 최근 5분 container restart 증가. rollout·logs --previous·describe pod 확인.`
- ⭐ 무엇이/어떻게/얼마나/**다음 행동**을 담아야 개발팀이 움직임.

### 한 줄 요약
> **좋은 alert는 metric 조건이 아니라 사람이 지금 해야 할 행동과 연결된다. `for`로 순간 spike를 거르고, threshold를 너무 낮추면 양치기 소년(alert fatigue)이 되어 진짜 장애를 놓친다.**

## 실습 확인 기록

### ① PrometheusRule 적용
```text
$ kubectl apply -f week4/day3/labs/observability-scenarios/prometheus-rule-preview.yaml
prometheusrule.monitoring.coreos.com/week4-observe-preview created

$ kubectl -n week4-observe get prometheusrule
NAME                    AGE
week4-observe-preview   0s
```
rule 내용:
```yaml
alert: Week4ObservePodRestarting
expr:  increase(kube_pod_container_status_restarts_total{namespace="week4-observe"}[5m]) > 0
for:   1m
labels:      { severity: warning }
annotations: { summary: "Pod restarted in week4-observe", description: "... Check rollout, logs, and events." }
```
- 읽는 포인트:
  - ⭐ `release: kube-prometheus-stack` label + values의 `ruleSelectorNilUsesHelmValues:false`(2교시) 덕에 Prometheus가 이 custom rule을 읽음.

### ② rule이 Prometheus에 반영되기까지 지연 (operator reconcile)
```text
# 적용 직후 rules API 조회
$ curl -s "http://kube-prometheus-stack-prometheus:9090/api/v1/rules?type=alert"
→ Week4ObservePodRestarting: NOT FOUND (아직 로드 안됨)

# ~25초 뒤 재조회
→ LOADED  state=firing  alerts=1
```
- 읽는 포인트:
  - ⚠️ `kubectl apply` 성공 ≠ 즉시 반영. PrometheusRule(CRD)→operator reconcile→Prometheus config reload에 **수십 초** 걸림. "바로 안 뜬다"고 rule 실패로 오판 금지(잠깐 기다림).

### ③ alert firing 확인 — crashloop만 울림
```text
$ curl -s "http://kube-prometheus-stack-prometheus:9090/api/v1/rules?type=alert"
state: firing  health: ok
  alert: firing  pod=crashloop-demo-6dfff677b9-qhpx5  severity=warning  value=1.11

# 참고: 조건값
increase(restarts[5m])  crashloop=1.11(>0)  cpu-pressure=0  readiness-bad=0
```
- 읽는 포인트:
  - ⭐ **crashloop만 firing**(restart 증가). cpu-pressure/readiness-bad는 restart가 없어 **이 alert에 안 걸림**.
  - ⚠️ 즉 이 restart 기반 alert는 **readiness 실패를 못 잡는다**(5교시 "restart만 보면 readiness 놓친다"가 alert 레벨에서도 그대로). readiness 장애까지 잡으려면 `kube_pod_status_ready` 기반 alert가 따로 필요.
  - ⚠️ 그리고 이 rule은 `increase[5m]>0`(restart 1회에도 발화) = 사실 **너무 민감**한 예시 → 운영이면 noise. `for`/threshold/사용자영향 결합으로 다듬어야 함.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| alert 상태 3가지? | inactive(불만족)/pending(만족+for 대기)/firing(for만큼 유지) |
| `for`가 왜 필요? | 순간 spike 거름. 배포 중 restart 1회 같은 정상 이벤트에 안 울리게 |
| threshold 너무 낮으면? | alert 폭주→끄거나 무시(alert fatigue, 양치기 소년)→진짜 장애 놓침 |
| Alertmanager 역할? | 보내는 게 아니라 grouping/routing/inhibition/silence로 다스림 |
| silence는 장애 해결? | 아님. 아는 작업/테스트 중 알림을 일정 시간 줄이는 것 |
| 이번에 발화한 건? | crashloop-demo만 firing(restart 증가). cpu/readiness는 안 걸림 |
| 이 alert의 약점 2가지? | ①readiness 장애 못 잡음(restart 기반) ②increase>0라 너무 민감(noise) |
| apply 직후 rule 안 보이면? | operator reconcile 지연. 수십 초 대기(즉시 반영 아님) |
| 좋은 alert 문장? | 무엇이/어떻게/얼마나 + 다음 행동(logs·describe) 포함 |

## notes

### Evidence Note
```markdown
# W4D3S6 Alert preview
- PrometheusRule: week4-observe-preview / alert Week4ObservePodRestarting
- expr: increase(kube_pod_container_status_restarts_total{namespace="week4-observe"}[5m]) > 0
- for: 1m, severity: warning
- 상태: firing (crashloop-demo, value 1.11) — reconcile 지연 후 ~25s만에 로드/firing
- 발화 범위: crashloop만. cpu-pressure/readiness-bad는 restart 없어 미발화
- noise가 될 수 있는 이유: increase>0(restart 1회)라 배포 중에도 울릴 수 있음
- 약점: restart 기반이라 readiness 실패(ready=0, restart=0)는 못 잡음
- silence가 필요한 상황: 계획된 배포/장애 테스트로 restart가 예상될 때
```

### 이 alert가 놓치는 것 (5교시와 연결)
```text
restart 기반 alert (Week4ObservePodRestarting)
  ✅ crashloop  잡음 (restart 증가)
  ❌ readiness 실패  못 잡음 (restart=0, ready=0)
  ❌ cpu 압박   못 잡음 (restart 없음)
```
- ⭐ alert도 "어떤 metric에 거느냐"가 곧 커버리지. readiness/CPU 장애까지 보려면 `kube_pod_status_ready`, CPU rate 기반 alert를 각각 추가해야 함. 하나의 alert가 모든 장애를 잡지 않는다.

### 양치기 소년 방지 (alert fatigue)
```text
threshold 너무 낮음 → alert 폭주 → 팀이 끄거나 무시 → 진짜 장애 때 못 잡음
```
- 다듬는 방향: ①`for`로 지속시간(10분+) ②사용자 영향 metric과 결합 ③severity 구분 ④runbook link. "많이"가 아니라 "적절히".

### 용어: threshold (임계값)
```text
threshold = 넘으면 뭔가 발동하는 기준선. alert의 "CPU > 80%"에서 80%가 threshold.
```
- ⭐ threshold **낮음**(예: CPU 50%) → 자주 넘음 → alert 폭주 → 양치기 소년. threshold **적절**(예: CPU 90% 10분↑) → 진짜 문제일 때만 발동.
- ⚠️ "임계점"보다 "임계값"이 정확한 번역. 물리의 상태변화점이 아니라 "이 값 넘으면 알림"의 기준선.

### Prometheus/Alertmanager UI (port-forward)
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090   # /alerts
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 # silence
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| apply 했는데 rules API에 rule이 없음 | operator reconcile→Prometheus reload 지연(수십 초). ~25s 뒤 LOADED+firing 확인. 즉시 반영 아님 |
| crashloop인데 한때 increase[5m]=0 | 지수 backoff로 간격 벌어짐(5교시). 이후 restart(16회)로 increase[5m]=1.11 → 조건 충족·firing |
| readiness-bad가 alert에 안 잡힘 | restart 기반 alert의 한계. ready=0이지만 restart=0이라 미발화 → ready 기반 alert 별도 필요 |
| alert가 너무 자주 울릴 위험 | increase>0는 restart 1회에도 발화 → 운영에선 for/threshold/영향결합으로 완화 |
