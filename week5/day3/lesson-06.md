# 6교시: CloudWatch Logs 기본

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| | |

## notes

- **로그 흐름**: `Container stdout/stderr → Log config(awslogs driver) → Log Group → Log Stream(task별) → Filter/Search`
- **읽는 순서 (3단계)**:
  - ① 먼저 **time range**를 장애 시점으로 맞춘다 (여기서 대부분 "로그 없음" 오판이 생김)
  - ② service/task/deployment에 해당하는 **log stream**을 고른다
  - ③ stream 안에서 **error, warning, startup message, request log**를 읽는다
- **log가 없을 때 첫 확인**:
  | 증상 | 첫 확인 |
  |---|---|
  | log group이 없음 | logging 설정(awslogs), service 생성 여부 |
  | log stream이 없음 | task가 **실제 실행**됐는가 (desired/running count) |
  | error가 안 보임 | app이 **stdout/stderr**로 출력하는가 |
  | 시간이 안 맞음 | **time range, Region** |
- **ECS logs**: task definition의 log configuration에 `awslogs` driver를 쓰면 container output이 CloudWatch Logs로. 확인 포인트 = log group(service 단위) / log stream prefix(task 구분) / timestamp(장애 시점) / error message(config·port·crash 원인)
- **App Runner logs**: build/deploy/app log가 나뉨. "어느 단계 로그인가"를 먼저 구분
  - deployment log: image pull/build/deploy 성공했는가
  - application log: app이 시작되고 요청을 처리하는가
  - service event: service 상태 전환이 있었는가
- **로그 vs 이벤트 구분**: app stack trace는 **log stream**에서, task가 왜 stopped됐는지는 **ECS task stopped reason / service event**에서 본다
- **장애 로그 해석 예시**:
  | 로그 | 해석 | 다음 확인 |
  |---|---|---|
  | `listen EADDRINUSE` | port 충돌 | container port / process |
  | `missing env` | config 누락 | env / secret 설정 |
  | `connection refused` (DB) | DB endpoint / SG | Day4 연결 |
  | `permission denied` | IAM/role/파일 권한 | task role, policy |
- **보존 정책**: 실습용 log group은 retention을 짧게. 무기한 보존은 비용보다 관리 부채가 문제

- 흔한 실패 3개:
  - ① 다른 **Region**의 log group을 봄
  - ② **time range**가 안 맞아 "로그 없음"으로 오판
  - ③ service는 **stopped**인데 log만 찾음 (task 실행 여부부터 확인해야 함)
- **한 줄 요약**: CloudWatch Logs는 container가 남긴 **stdout/stderr를 운영 증거로 모으는 곳**이다

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
