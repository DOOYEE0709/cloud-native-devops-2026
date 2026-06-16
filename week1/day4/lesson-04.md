# 4교시: 네이버 - 데이터베이스, 저장소, 검색, 서빙

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 데이터가 코드와 다른 이유를 설명할 수 있는가? | frontend는 다시 build할 수 있고 backend process는 재시작할 수 있지만, 사용자 데이터와 검색 문서, 주문 기록, 로그는 사라지면 안 된다. 데이터는 코드와 달리 재생성이 불가능하거나 매우 어렵다. |
| DB 실행 조건으로 port, version, data path를 말할 수 있는가? | 예: MySQL은 port 3306, version 8.x, data directory `/var/lib/mysql`. PostgreSQL은 port 5432, version 15.x. 버전과 포트가 다른 프로젝트를 동시에 실행하면 충돌이 생긴다. |
| 데이터 비용 또는 신뢰성 challenge 1개를 설명할 수 있는가? | 데이터가 커질수록 storage 비용이 증가하고, 색인 크기가 커져 검색 속도가 느려진다. freshness를 유지하려면 실시간 업데이트나 캐시 무효화 비용이 발생한다. |
| Docker 관점에서 DB가 중요한 이유는 무엇인가? | DB 설치는 한 번이면 끝나는 것처럼 보이지만 두 번째 프로젝트가 다른 버전이나 다른 포트를 요구하면 바로 문제가 된다. Docker volume, port, initialization script가 중요해진다. |

## notes

### 데이터 책임 지도

| 책임 | 의미 | 로컬 버전 |
|---|---|---|
| Persistence | 재시작 후에도 남는 데이터 | file 또는 database volume |
| Schema | 데이터 구조 | table 또는 JSON shape |
| Index | 빠른 조회 경로 | DB index 또는 search index |
| Backup | 손실 후 복구 | copied file 또는 dump |
| Migration | 구조 변경 절차 | SQL migration 또는 script |
| Freshness | 얼마나 최신 데이터를 보여주는가 | reload 또는 cache invalidation |

### Database contract 템플릿

```text
Database type: (예: PostgreSQL, MySQL, SQLite)
Version: (예: PostgreSQL 15.x)
Port: (예: 5432)
Data path: (예: /var/lib/postgresql/data)
Seed data: (예: init.sql 또는 products.json)
Reset command: (예: docker volume rm db-data)
Backup method: (예: pg_dump)
What must not be deleted: (예: 사용자 데이터, 주문 기록)
```

### AI 엔지니어링 연결

AI 서비스에서 데이터 파이프라인:
```text
수집 → 정제 → chunking → embedding → vector index → retrieval → monitoring
```

"AI에게 문서를 넣는다"는 말은 이 전체 파이프라인을 의미한다. Docker 관점에서는 vector DB, embedding worker, API 서버를 같은 조건으로 실행하고 초기화할 수 있어야 한다.

### Docker 연결

```text
"DB 설치는 한 번이면 끝나는 것처럼 보입니다.
하지만 두 번째 프로젝트가 다른 버전이나 다른 포트를 요구하면 바로 문제가 됩니다.
DB에는 생명주기가 있고, 그래서 Docker volume, port, initialization script가 중요해집니다."
```

### 핵심 관점

```text
데이터 시스템은 코드보다 더 오래 살아남는다.
서비스가 바뀌고 코드가 다시 쓰여도 데이터는 남는다.
그래서 데이터 운영은 저장, 색인, 백업, migration, freshness, latency를 함께 고민한다.
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
