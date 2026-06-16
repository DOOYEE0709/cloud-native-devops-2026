# 7교시: 여기어때 - 폭주 트래픽, 쿠폰, Redis, Kafka

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| peak traffic이 average traffic과 다른 이유를 설명할 수 있는가? | 평균 traffic만 보면 이벤트 실패를 예측하기 어렵다. 하루 종일 안정적인 서비스도 쿠폰 오픈 1분 동안 무너질 수 있다. API 서버, DB write, cache consistency, queue lag, dashboard에 동시에 압력이 가해진다. |
| 선착순 이벤트에서 cache와 queue 위치를 말할 수 있는가? | cache(Redis)는 빠른 재고 카운트 확인(atomic count)에 사용하고, queue(Kafka)는 당첨 처리를 비동기로 넘기는 데 사용한다. 빠른 check → queue message → final write 순서다. |
| disposable environment가 필요한 이유 1개를 쓸 수 있는가? | 선착순 이벤트 테스트는 초기 상태(쿠폰 수량, Redis 카운터, queue 상태)를 매번 리셋해야 한다. 한 번 쓰고 지울 수 있는 환경이 없으면 테스트 반복이 어렵다. |
| AI 이상 탐지가 rate limit보다 먼저여야 하는가? | 아니다. 폭주 상황에서는 AI 판단보다 먼저 rate limit, queue, cache counter 같은 deterministic control이 필요하다. AI 이상 탐지는 운영자를 돕는 보조 장치다. |

## notes

### Traffic 유형 비교

| traffic 유형 | 주요 위험 | 시스템 대응 |
|---|---|---|
| 평시 traffic | 완만한 증가 | 점진적 scale |
| 캠페인 traffic | 짧은 spike | rate control, queue |
| 선착순 traffic | 공정성, oversell | atomic count, lock |
| 예약 traffic | 중복 action | idempotency, validation |
| 결제 traffic | 데이터 손실 | transaction, retry |

### Burst event 설계 템플릿

```text
Event: (예: 쿠폰 선착순 오픈)
Open time: (예: 오전 10:00)
Maximum winners: (예: 1,000명)
User action: (예: 쿠폰 발급 버튼 클릭)
Fast check: (예: Redis DECR으로 남은 수량 확인)
Queue message: (예: Kafka topic에 당첨자 정보 발행)
Final write: (예: DB에 쿠폰 발급 기록 저장)
Dashboard metric: (예: 발급 수, 실패 수, queue lag)
Failure to prevent: (예: oversell, 중복 발급)
```

### 핵심 흐름

```text
사용자 요청 → rate limit check → Redis atomic count
                                  ↓ (당첨)
                              Kafka topic에 message 발행
                                  ↓
                          consumer가 DB에 최종 기록
                                  ↓
                          dashboard에서 확인
```

### Docker 연결

```text
disposable Redis/queue/test data가 필요하다.
→ Docker는 테스트 환경을 반복 생성/정리할 수 있게 해준다.
  docker compose up → 테스트 실행 → docker compose down --volumes
  이 사이클이 이벤트 테스트의 기본 단위가 된다.
```

### AI 엔지니어링 연결

- AI는 비정상 트래픽 탐지, 이벤트 성공률 예측, 장애 알림 우선순위화에 붙을 수 있다.
- 실제 방어선은 명시적인 rate limit과 atomic count다.
- AI는 운영자에게 "지금 이상 패턴이 보인다"고 알려주는 보조 역할이다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
