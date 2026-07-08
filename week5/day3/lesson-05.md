# 5교시: 배포 변경과 rollback preview

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| rollback 전에 반드시 기록할 것은? | 이전 정상 image tag, task definition revision, service 상태, target health, endpoint 응답이다. 이 값이 있어야 어디로 되돌릴지 정할 수 있다 |
| `latest` tag만 쓰면 왜 위험한가? | `latest`는 시간이 지나면 어떤 image였는지 추적하기 어렵다. rollback하려고 해도 이전 정상 image를 증명하기 힘들다 |
| ECS에서 rollback은 보통 어떻게 하나? | 새 image를 반영한 task definition revision이 실패하면, service를 이전 정상 task definition revision으로 다시 update한다 |
| App Runner에서 rollback 사고방식은? | deployment history와 image source를 보고 이전 정상 image tag로 다시 배포한다. 핵심은 "이전 정상 tag가 무엇인지 알고 있는가"이다 |
| health check 실패는 무조건 image rollback인가? | 아니다. health check path, container port, security group 설정 문제일 수 있다. image 문제인지 설정 문제인지 먼저 분리한다 |

## notes

- **배포 변경 흐름**: `Image v1 정상 -> Image v2 배포 -> Health/Logs 확인 -> 유지 또는 rollback`
- Container 배포에서 변경 단위는 보통 **image tag**와 **task definition revision**이다.
  - ECR image tag: 어떤 image를 배포했는지
  - ECS task definition revision: service가 어떤 실행 정의를 쓰는지
  - deployment event/history: 언제 어떤 변경이 들어갔는지
- **rollback은 감으로 되돌리는 작업이 아니다**
  - 변경 전 정상 상태를 기록해야 한다.
  - 이전 tag/revision을 모르면 rollback 기준이 없다.
  - "아까 됐는데"가 아니라 `image=v1`, `revision=3`, `target=healthy`, `curl=200`처럼 남겨야 한다.
- **변경 전 evidence**
  - previous image tag
  - previous task definition revision 또는 App Runner image source
  - desired/running count
  - target health 또는 service status
  - endpoint 응답
  - 주요 log error 없음
- **변경 후 evidence**
  - new image tag
  - new task definition revision 또는 deployment id
  - deployment status
  - running count
  - target health
  - CloudWatch/App Runner logs
  - endpoint 응답
- **실패 시나리오 구분**
  - image pull 실패: ECR URI, tag, IAM 권한, region 확인
  - container crash: stopped reason, application log 확인
  - wrong port: task definition portMappings, target group port, App Runner port 확인
  - wrong health path: target group health check path와 실제 app endpoint 대조
  - wrong env/config: env var, secret, app log 확인
  - latency 증가: metric을 보고 rollback, scale 조정, DB/network 병목을 판단
- **rollback 우선순위**
  - 새 image가 pull도 안 됨 → 이전 revision/tag로 빠르게 rollback
  - 새 task가 계속 crash → rollback 우선
  - health check path/port 설정 실수 → 설정 수정으로 해결 가능할 수 있음
  - latency만 증가 → metric과 log를 보고 rollback 또는 scale/config 조정
- **ECS rollback preview**
  - image tag 변경 시 보통 새 task definition revision을 만든다.
  - service update로 새 revision을 반영한다.
  - 실패하면 service를 이전 정상 revision으로 다시 update한다.
- **App Runner rollback preview**
  - App Runner는 ALB/target group이 덜 보이지만 deployment status와 logs를 봐야 한다.
  - 이전 정상 image tag를 알고 있어야 같은 source로 다시 배포할 수 있다.
- **운영에서 중요한 태도**
  - 배포 성공은 "update 명령 성공"이 아니라 health, logs, endpoint까지 확인한 상태다.
  - 실패 배포를 방치하면 task 재시작, log 증가, 불안정한 service 상태가 이어진다.
  - rollback 후에도 endpoint와 logs를 다시 확인해야 한다.
- **Evidence template**

```markdown
Before: image=v1, revision=3, target=healthy, curl=200
Change: image=v2, revision=4
Check: target=unhealthy, logs=port error
Action: service update to revision=3
Recheck: target=healthy, curl=200
```

- 흔한 실패 3개:
  - ① `latest`만 써서 이전 정상 image를 모름
  - ② health/log 확인 없이 배포 성공으로 기록함
  - ③ rollback할 revision/tag를 기록하지 않음

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
