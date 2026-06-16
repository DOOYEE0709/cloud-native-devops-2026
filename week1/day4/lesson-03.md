# 3교시: 당근 - 백엔드와 서비스 경계

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| backend service contract를 하나 작성할 수 있는가? | Service name, Purpose, Run command, Port, Required environment variables, Required database or file, Health check URL, Log location, What breaks if this service is down을 채운다. |
| 공통 서비스가 위험해지는 이유 1개를 설명할 수 있는가? | 인증, 결제, 알림 같은 공통 서비스가 장애 나면 이를 의존하는 모든 서비스가 동시에 영향을 받는다. 경계 없이 의존성이 많아질수록 장애 영향 범위가 커진다. |
| service boundary와 runtime boundary는 어떻게 연결되는가? | service boundary가 명확하면 각 service가 독립 runtime에서 실행될 수 있다. 이것이 Docker container로 격리하고 독립 배포하는 기반이 된다. |
| "MSA가 항상 정답"이 아닌 이유는 무엇인가? | 비즈니스 책임과 운영 위험에 맞게 경계를 잡아야 한다. 규모가 작을 때 모놀리식이 더 운영하기 쉬울 수 있다. 경계 분리는 독립 배포와 장애 격리가 필요할 때 도입한다. |

## notes

### 백엔드 경계 질문

| 질문 | 중요한 이유 |
|---|---|
| 이 데이터는 누가 소유하는가? | 아무 서비스나 중요한 상태를 바꾸지 못하게 한다. |
| 누가 이 API를 호출할 수 있는가? | 권한과 신뢰 경계를 보호한다. |
| 실패하면 무엇이 멈추는가? | 장애 영향 범위를 파악한다. |
| 독립 배포가 가능한가? | release coupling을 줄인다. |
| 정상 상태를 어떻게 확인하는가? | 운영자가 볼 health check를 만든다. |

### Backend service contract 템플릿

```text
Service name:
Purpose:
Run command:
Port:
Required environment variables:
Required database or file:
Health check URL:
Log location:
What breaks if this service is down:
```

### AI 엔지니어링 연결

백엔드에서 AI 기능이 추가될 때 새로운 실행 조건:
- LLM API를 호출하려면 → 권한, 입력 검증, audit log가 더 중요해진다.
- prompt, model endpoint, token 비용, rate limit도 실행 조건으로 관리해야 한다.

### Docker 연결

```text
서비스 경계가 생기면 각 service마다 다른 runtime, port, config가 필요하다.
→ Docker는 각 service runtime을 격리하고 반복 실행할 수 있게 해준다.
  여러 service를 함께 실행할 때는 Docker Compose가 필요해진다.
```

### 핵심 문장

```text
중요한 것은 "MSA가 항상 정답"이 아니라,
비즈니스 책임과 운영 위험에 맞게 경계를 잡아야 한다는 점이다.
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
