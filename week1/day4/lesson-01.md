# 1교시: 쿠팡 - 현대 애플리케이션 전체 구성 지도

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 상품 페이지 뒤의 구성요소 5개 이상을 말할 수 있는가? | 상품 카탈로그, 가격, 재고, 이미지 저장소, 배송 약속, 리뷰, 추천 등이 있다. 사용자에게 하나의 화면처럼 보이지만 뒤에서는 여러 책임이 만난다. |
| 비즈니스 증가 요인 1개와 운영 부담 1개를 연결할 수 있는가? | 상품 수 증가 → catalog storage, image storage, search indexing 부담 증가. 사용자 수 증가 → API 처리량, cache hit rate, monitoring 부담 증가. |
| Docker 명령 없이 Docker가 필요한 이유를 한 문장으로 쓸 수 있는가? | 여러 구성요소의 실행 조건(runtime, dependency, port, config, data)을 모든 개발자가 같은 상태로 설치하고 실행하기 어렵기 때문에 Docker로 포장하고 재현한다. |
| 커머스 서비스에서 AI가 들어가면 추가 실행 조건은 무엇인가? | 모델 서버, feature data, batch job, GPU/CPU 비용, 실험 추적이 추가 실행 조건이 된다. Docker 관점에서는 추천 API runtime, 모델 파일 위치, 실험용 데이터 초기화 방법이 필요하다. |

## notes

### 커머스 앱 구성요소

| 구성요소 | 역할 | 로컬 버전 |
|---|---|---|
| Frontend | 상품 화면 표시 | `index.html` 상품 화면 |
| Backend | API, 비즈니스 로직 처리 | 간단한 API process |
| Data | 상품/주문/사용자 데이터 | `products.json` |
| Cache | 빠른 읽기를 위한 임시 저장 | browser cache |
| Queue | 비동기 이벤트 처리 | (Day4에서 다룸) |
| Network | 요청 라우팅, CDN | `localhost:8000` |
| Config | 환경별 설정 | `.env` 또는 hard-coded value |

### 비즈니스 증가와 시스템 노력

| 비즈니스 증가 | 함께 늘어나는 시스템 노력 |
|---|---|
| 상품 수 증가 | catalog storage, image storage, search indexing |
| 사용자 수 증가 | API 처리량, cache hit rate, monitoring |
| 판매자 수 증가 | 데이터 소유권, 검증, 권한 규칙 |
| 주문 수 증가 | 재고 정합성, queue 처리, retry |
| 지역 증가 | network latency, 배송 로직, traffic routing |

### 로컬 앱 vs 실제 회사 비교

| 구성요소 | 작은 로컬 버전 | 실제 회사 버전 |
|---|---|---|
| Frontend | `index.html` 상품 화면 | web/mobile product page |
| Backend | 간단한 API process | 여러 domain service |
| Data | `products.json` | database, data platform |
| Cache | browser cache | distributed cache |
| Queue | 아직 없음 | order/event pipeline |
| Network | `localhost:8000` | CDN, load balancer, internal network |
| Config | `.env` 또는 hard-coded value | environment config, secret |

### Docker 연결

Docker는 커머스 비즈니스 문제를 해결하는 도구가 아니다. 하지만 이런 서비스가 실행되기 위한 조건을 포장하고 재현하기 위한 첫 번째 도구가 된다.

```text
수동 설치의 고통:
각자 다른 Node.js 버전, Python 버전, DB 포트로 설치하면
"내 컴퓨터에서는 됩니다"가 반복된다.
Docker는 이 실행 조건을 image로 묶어 재현 가능하게 만든다.
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
