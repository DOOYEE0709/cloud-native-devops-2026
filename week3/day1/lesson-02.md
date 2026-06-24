# 2교시: Monolith vs MSA

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker compose config` | 출력에서 `published: "18083"`(외부 진입점), `DB_HOST: db`, `API_URL: http://api:8080/api/status` 줄을 찾아 service 간 연결을 확인 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 이 앱을 Monolith로 만들면 무엇이 단순해지는가? | service 주소 관리, timeout/retry, 로그 분산, 배포 순서 같은 운영 비용이 사라진다. 함수 호출로 통신하고 하나만 배포하면 된다. |
| MSA로 나누면 무엇을 독립적으로 바꿀 수 있는가? | service별로 독립 배포가 가능하다. api만 고쳐 배포하거나 worker만 재시작하는 식으로 다른 service에 영향 없이 변경할 수 있다. |
| DB가 죽으면 어떤 service가 영향받는가? | api는 DB 연결 실패로 503/error를 내고, worker도 api 호출이 실패해 로그를 남긴다. 장애가 db → api → worker로 전파된다. |
| worker가 죽으면 사용자는 바로 알 수 있는가? | 알기 어렵다. worker는 background 경로라 사용자 화면은 정상으로 보일 수 있다. 그래서 worker log를 따로 확인해야 한다. |

## notes

### 시작 질문 — 보는 관점이 바뀐다

```text
하나의 process가 죽었는가?
  ↓
어느 service가 죽었고, 그 영향이 어디까지 전파되었는가?
```

서비스가 나뉘는 순간 인프라가 확인할 것이 늘어난다. MSA는 "작게 나누면 좋은 것"이 아니라 운영 비용을 지불하는 구조다.

### Monolith vs MSA 비교

| 관점 | Monolith | MSA |
|---|---|---|
| 배포 단위 | 하나의 애플리케이션 | 여러 service |
| 장애 영향 | 한 process 문제가 전체 장애로 이어지기 쉬움 | 특정 service만 실패할 수 있지만 전파 가능 |
| 통신 방식 | 함수 호출, 같은 process 내부 | HTTP/gRPC/message queue 등 network 호출 |
| 데이터 책임 | 하나의 DB를 함께 쓰는 경우가 많음 | service별 data ownership 고려 |
| 배포 속도 | 전체 배포 필요 | service별 독립 배포 가능 |
| 운영 복잡도 | 상대적으로 낮음 | service discovery, observability, retry, timeout 필요 |
| 테스트 기준 | 전체 앱 기능 확인 | service 계약과 통합 흐름 확인 |

### 시나리오 1: 작은 사내 관리 도구 → Monolith가 유리

| 이유 | 설명 |
|---|---|
| 장애 범위가 작음 | 사용자가 적고 복구 시간이 짧아도 감당 가능 |
| 팀 규모가 작음 | service별 ownership을 나눌 필요가 적음 |
| 운영 인력이 적음 | MSA 운영 도구를 유지할 비용이 큼 |
| 배포 빈도가 낮음 | 독립 배포의 이점이 작음 |

### 시나리오 2: 커머스 서비스 → MSA가 도움

상품·주문·결제·배송·알림이 모두 같은 배포 단위면 한 기능 변경이 전체 배포 위험이 된다.

```text
catalog service: 상품 조회
order service: 주문 생성
payment service: 결제 승인
notification worker: 알림 발송
```

하지만 나누면 새 문제가 생기고, 인프라가 준비해야 한다.

| 새 문제 | 인프라가 준비할 것 |
|---|---|
| service 주소 관리 | service name, DNS, gateway |
| 장애 전파 | timeout, retry, circuit breaker 논의 |
| 로그 분산 | request id, correlation id |
| 데이터 일관성 | transaction boundary, eventual consistency |
| 배포 순서 | version compatibility, rollback 기준 |

### 로그 통합 — correlation id와 비용 트레이드오프

위 표의 "로그 분산 → request id, correlation id" 항목 보강.

MSA는 요청 하나가 여러 service를 거치는데, 각 service가 자기 로그를 따로 남긴다. 장애 시 frontend/api/worker 로그를 따로 뒤져야 하고 같은 요청인지 알 수 없다.

**해결: correlation id(= request id, trace id)**. 요청 진입 시 고유 ID를 발급해 모든 service 호출에 전파하면, 그 ID로 흩어진 로그를 하나의 요청 흐름으로 묶을 수 있다.

```text
요청 진입 → request-id: abc123 발급
frontend  로그: [abc123] 요청 받음
api       로그: [abc123] DB 조회
worker    로그: [abc123] 처리 완료   → abc123으로 검색하면 한 흐름으로 통합
```

msa-demo도 준비되어 있다: `api.environment.REQUEST_ID_HEADER: x-request-id`.

**도구 선택과 비용 트레이드오프:**

| 구분 | 예시 | 특징 |
|---|---|---|
| SaaS (관리형) | Datadog, New Relic, Splunk, Grafana Cloud | 편하지만 로그량(GB)에 비례해 과금 |
| 자체 구축 (오픈소스) | ELK, Loki, OpenTelemetry+Jaeger | 직접 운영해야 하지만 대규모에선 더 쌈 |

규모가 작을 땐(월 몇천 수준) SaaS가 인건비보다 싸서 그냥 쓰지만, 트래픽이 커져 연 억 단위로 과금이 넘어가면 그 돈으로 엔지니어를 붙여 자체 구축하는 게 더 싸지는 분기점이 온다. → "억 넘어가면 SaaS 포기하고 자체 개발".

### service를 나눈다 = repo? 브랜치?

브랜치 기준이 아니다. 브랜치는 같은 코드베이스의 작업 흐름을 나누는 것일 뿐, service 분리 단위가 아니다. service를 나눈다 = **배포 단위(빌드·릴리스되는 이미지)를 나눈다**.

| 방식 | 구조 | 특징 |
|---|---|---|
| Polyrepo | service마다 repo 따로 | 독립 배포 파이프라인·권한 분리가 깔끔, repo가 많아짐 |
| Monorepo | 한 repo + service는 디렉터리 | 공통 코드·검색 쉬움, "바뀐 service만 빌드" 설정 필요 |

핵심: repo 개수가 기준이 아니라 **배포 단위가 독립인가**가 기준. monorepo여도 배포는 service별로 독립적이다.

msa-demo가 monorepo 축소판이다 — 폴더(repo)는 하나지만 `api/`, `worker/`가 각자 Dockerfile로 빌드되는 독립 이미지라 **배포 단위는 분리**되어 있다.

```text
msa-demo/                          ← repo 하나
  api/    Dockerfile + app.py      ← 독립 service / 독립 이미지
  worker/ Dockerfile + worker.py   ← 독립 service / 독립 이미지
```

### service 분리는 개발팀과의 협상이다 (granularity)

MSA에서 service를 얼마나 잘게 쪼갤지는 개발팀 마음대로가 아니라 **인프라 운영 비용과의 협상**이다. 개발팀은 코드 관점에서 자꾸 나누고 싶어하고, 인프라팀은 너무 많이 나뉘면 네트워크·운영을 감당하기 힘들다.

| | 개발팀이 나누고 싶은 이유 | 인프라팀이 걱정하는 것 |
|---|---|---|
| 관점 | 코드 독립성, 팀별 ownership, 독립 배포 | 운영 가능한 service 개수, 네트워크 복잡도 |
| 방향 | 많이 나눌수록 책임 분리 깔끔 | 적을수록 관리 단순 |

위 "새 문제" 표의 부담이 **service 개수에 비례해 폭증**한다.

```text
service 5개  → 통신 경로 관리 가능
service 50개 → 주소·DNS·timeout·retry·로그·배포순서 전부 N배
```

| 늘어나는 것 | 부담 |
|---|---|
| 통신 경로 | N개면 연결 조합 폭증 (network mesh) |
| 주소·DNS·gateway | service마다 등록·라우팅 |
| 장애 전파 추적 | hop이 길어짐 |
| 배포 순서·호환성 | 버전 의존이 거미줄 |
| 네트워크 보안 | 경계·정책이 service 수만큼 |

**그래서 타협한다**: "이건 굳이 분리해야 해요? 합쳐도 되지 않아요?" — 거의 항상 같이 호출되고 데이터가 엮인 service는 지금 단계엔 합쳐두고, 트래픽이 커지면 그때 분리.

- 너무 잘게 → 운영·네트워크 지옥 (인프라 비명)
- 너무 안 나눔 → Monolith의 배포 위험 (개발팀 비명)
- 기준: **독립 배포가 정말 필요한 경계만 나눈다. "나눌 수 있다 ≠ 나눠야 한다".**

너무 잘게 쪼개 서로 엮여 독립 배포도 안 되는 최악을 **nano service / 분산 monolith**라 부른다. 적정 크기를 찾는 것을 **right-sizing**.

### 실습 앱(msa-demo)에 적용하기

| 질문 | `msa-demo`에서 보는 위치 |
|---|---|
| 사용자는 어디로 들어오는가 | `frontend` host port `18083` |
| API는 어디에 있는가 | `api:8080`, debug port `18084` |
| API는 DB를 어떻게 찾는가 | `DB_HOST=db`, `DB_PORT=5432` |
| worker는 누구를 호출하는가 | `API_URL=http://api:8080/api/status` |
| DB data는 어디에 남는가 | `msa-db-data` volume |

### 핵심

MSA는 더 작은 코드를 만드는 기술이 아니라, 여러 service를 독립적으로 배포하고 운영하기 위해 복잡도를 받아들이는 구조다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
