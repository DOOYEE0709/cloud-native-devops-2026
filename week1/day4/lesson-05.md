# 5교시: 카카오 - 메시지 스트리밍과 비동기 이벤트

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| producer, queue/topic, consumer를 설명할 수 있는가? | producer는 이벤트를 만들어 queue/topic에 넣는 서비스, consumer는 queue/topic에서 이벤트를 읽어 처리하는 서비스다. 둘은 직접 연결되지 않아 결합도가 낮다. |
| async 처리가 결합도를 낮추는 이유 1개를 말할 수 있는가? | producer가 consumer의 응답을 기다리지 않으므로 consumer가 느리거나 죽어도 producer가 영향을 받지 않는다. 이벤트를 queue에 남겨두고 consumer가 준비되면 처리한다. |
| queue가 새로 만드는 운영 부담 1개를 말할 수 있는가? | consumer lag(처리 지연), retry 설계, Dead Letter Queue(처리 실패 이벤트 보관), ordering 보장, monitoring이 필요해진다. 단순 API 호출보다 운영 복잡도가 높아진다. |
| AI worker를 비동기로 처리해야 하는 이유는 무엇인가? | AI worker는 일반 API보다 느릴 수 있으므로 동기 처리하면 caller가 오래 기다린다. 비동기 처리, retry, DLQ 설계가 더 중요해진다. |

## notes

### Sync vs Async 비교

| 방식 | 형태 | 좋은 점 | 위험 |
|---|---|---|---|
| Synchronous API | 요청이 응답을 기다림 | 즉시 결과 필요 | 장애 전파가 빠름 |
| Queue | producer가 task를 넣고 worker가 처리 | background 작업 | 지연 처리와 retry 설계 필요 |
| Event stream | 여러 consumer가 event를 구독 | 여러 서비스 확장 | ordering, lag, monitoring 필요 |

### Event flow 실습 템플릿

```text
User action:
Producer service:
Message name:
Queue or topic:
Consumer service:
What can run later:
What must be retried:
What log proves it worked:
```

### 핵심 설명

한 서비스가 다른 서비스를 직접 호출하면 caller는 receiver의 응답을 기다린다. 단순하지만 결합도가 높다. receiver가 느리거나 죽으면 caller도 영향을 받는다.

Queue나 event stream은 이벤트를 남겨 두고 다른 service가 나중에 처리하게 만든다.

### AI 엔지니어링 연결

AI 기능이 이벤트 기반으로 붙는 경우:
- 문의가 들어오면 분류 worker가 돌고
- 장애 이벤트가 생기면 AI가 요약한다

이벤트가 많아질수록 AI 요약, 이상 탐지, 자동 알림도 queue/stream 위에서 동작한다.

### Docker 연결

```text
queue는 port, data, startup order, log를 가진다.
→ broker와 consumer 실행 순서가 중요하다.
  broker가 먼저 떠야 consumer가 연결할 수 있다.
  Docker Compose의 depends_on이 이 순서를 관리한다.
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
