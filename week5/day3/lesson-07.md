# 7교시: CloudWatch Metrics와 Alarm

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Logs와 Metrics의 차이는? | Logs는 **무슨 일이 있었나**(event/text, error stack), Metrics는 **얼마나 자주/크게 일어났나**(number over time, CPU·5xx count). 도구도 log group vs metrics/graph/alarm으로 나뉨 |
| namespace / metric / dimension은? | **namespace**=service 묶음(`AWS/ECS`, `AWS/ApplicationELB`), **metric**=관찰 수치(CPUUtilization), **dimension**=어떤 resource인지 구분하는 label(ClusterName/ServiceName). dimension 없으면 "어떤 service의 CPU인지" 모름 |
| Alarm의 3요소는? | **threshold**(임계값), **period/evaluation**(몇 분 단위로 몇 번 볼지), **state**(OK/ALARM/INSUFFICIENT_DATA). 조건을 만족하면 state가 바뀜 |
| 좋은 metric의 기준은? | **다음 운영 행동으로 이어지는가**. CPU↑→scale/size 검토, 5xx↑→app error 조사, unhealthy host↑→target health 확인. 그래프를 예쁘게 만들려는 게 아니라 행동을 빨리 정하기 위함 |
| ALB target metric을 따로 보는 이유는? | app task만 보면 **user traffic 관점 장애를 놓침**. TargetResponseTime·5xx·UnHealthyHostCount는 사용자가 실제로 겪는 장애 징후 |
| INSUFFICIENT_DATA는 왜 생기나? | metric이 아직 **안 쌓였거나** period 안에 데이터가 없음. 갓 만든 service나 traffic 없는 구간에서 정상적으로 나옴 — 장애로 오판 금지 (`treat-missing-data`로 처리) |
| Alarm을 너무 빨리 만들면? | threshold 이해 없이 만들면 **noise**가 됨. 어떤 metric에 어떤 threshold를 걸면 어떤 행동을 할지부터 정하고 만들어야 함 |

## notes

- **구조**: `Service → Metric namespace → Dimension → CloudWatch graph → Threshold 후보 → Alarm state → Operations action`
- **Logs vs Metrics**:
  | 구분 | Logs | Metrics |
  |---|---|---|
  | 형태 | event / text | number over time |
  | 예시 | error stack, request log | CPUUtilization, 5xx count |
  | 질문 | 무슨 일이 있었나 | 얼마나 자주/크게 일어났나 |
  | 도구 | Log groups/streams | Metrics/graphs/alarms |
- **대상별 볼 metric**:
  | 대상 | metric 예시 | 질문 |
  |---|---|---|
  | EC2 | CPUUtilization, NetworkIn/Out | instance가 과부하인가 |
  | ECS | CPU/Memory utilization | service resource가 부족한가 |
  | App Runner | request count, latency, 5xx 계열 | managed service가 응답하는가 |
  | ALB | TargetResponseTime, HTTPCode_Target_5XX_Count, UnHealthyHostCount | user traffic이 정상인가 |
- **Alarm preview 흐름**: `Metric → Threshold → Evaluation → Alarm State`
  | Alarm state | 의미 |
  |---|---|
  | OK | 조건 미충족, 정상 범위 |
  | ALARM | 조건 충족 |
  | INSUFFICIENT_DATA | 판단할 데이터 부족 |
- **metric → 다음 행동 매핑**:
  | 상황 | metric | 다음 행동 |
  |---|---|---|
  | task가 느림 | CPU/Memory utilization | resource/scale 확인 |
  | 사용자가 오류 경험 | ALB 5xx, App Runner 5xx | logs와 deployment 확인 |
  | target 장애 | UnHealthyHostCount | target health reason |
  | traffic 증가 | RequestCount | scale/cost 확인 |
- **노이즈 없는 alarm은 처음부터 안 나온다 (실무 관점)**:
  - 처음부터 딱 맞는 threshold를 잡는 건 **현업 엔지니어도 어렵다**. 완벽한 값을 고민하다 alarm을 안 만드는 것보다, 일단 걸고 **디벨롭**하는 게 낫다.
  - 흐름: **처음엔 다소 민감하게 걸어 alarm을 받아본다 → 실제로 문제였는지 판단 → 오탐(noise)이면 threshold를 올리거나 evaluation-periods를 늘린다 → 반복하며 조인다.**
  - 즉 alarm은 "한 번 만들고 끝"이 아니라 **운영하면서 튜닝하는 규칙**이다. 처음 threshold는 정답이 아니라 **출발점**.
  - 조정 손잡이: `--threshold`(임계값 상향), `--evaluation-periods`(연속 N회 충족 시만), `--period`(관찰 창), `--datapoints-to-alarm`(M/N), `--treat-missing-data`(데이터 없을 때 처리).
  - 반대 방향 실패도 있음: threshold를 너무 관대하게(높게) 잡으면 **진짜 장애를 놓친다**. 그래서 noise ↔ miss 사이에서 반복 조정하는 것.
- **캡처 가이드**: metric graph는 **time range, metric name, dimension**이 보이게. alarm preview는 **threshold와 state**가 보이면 충분

- 흔한 실패 3개:
  - ① metric이 아직 **안 쌓였는데** 장애로 판단 (INSUFFICIENT_DATA)
  - ② **Region**이 다름
  - ③ 로그에서 봐야 할 **error를 metric에서** 찾음 (Logs/Metrics 역할 혼동)
- **한 줄 요약**: CloudWatch Metrics는 상태를 **숫자로 보고**, Alarm은 그 숫자에 **운영 기준**을 붙인다

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
