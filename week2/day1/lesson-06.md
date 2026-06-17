# 6교시: Week 1 로컬 PostgreSQL 정리와 DB 컨테이너 준비

## 실습 확인 기록

| 명령/확인 | 설명 | 결과 |
|---|---|---|
| `psql --version` | PostgreSQL client/server 설치 여부 확인 | ![psql --version](assets\lesson-06\psql-version.png) |
| `pg_isready` | local PostgreSQL server 실행 여부 확인 | ![pg_isready](assets\lesson-06\pg-isready.png) |
| `lsof -i :5432` | host port 5432 점유 여부 확인 (macOS/Linux) | ![lsof -i :5432](assets\lesson-06\lsof-i-5432.png) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| `psql --version`이 나오면 PostgreSQL이 실행 중인가? | 아니다. client package가 설치됐다는 뜻이지 server가 실행 중이라는 뜻이 아니다. `pg_isready`로 server 실행 여부를 따로 확인해야 한다. |
| host port 5432가 이미 사용 중이면 어떻게 해야 하는가? | 세 가지 선택이 있다. 기존 DB 삭제 / 기존 DB 중지 / Docker host port를 15432, 15433처럼 다르게 잡고 그냥 두기. 무조건 삭제하지 않는다. |
| container 내부 port가 둘 다 5432인데 동시에 실행 가능한가? | 가능하다. container 내부 port는 각 container 안에서 독립적이다. host port를 15432, 15433으로 다르게 잡으면 동시에 접속할 수 있다. |
| PostgreSQL 16과 18 volume을 같이 써도 되는가? | 안 된다. version별로 PGDATA 경로와 데이터 포맷이 다를 수 있어서 섞으면 데이터가 깨질 수 있다. volume을 따로 만들어야 한다. |

## notes

### 로컬 PostgreSQL 상태 확인

```bash
psql --version      # client/server package 설치 여부
pg_isready          # server 실행 여부
lsof -i :5432       # port 5432 점유 여부 (macOS/Linux)
```

Linux에서 `lsof`가 없으면:
```bash
ss -ltnp | grep ':5432'
```

| 증상 | 의미 | 다음 행동 |
|---|---|---|
| `psql --version`만 나옴 | package 설치됨, server 실행 여부 불명 | `pg_isready` 확인 |
| `pg_isready` accepting connections | local server 실행 중 | 삭제/중지/보류 선택 |
| `:5432` listener 보임 | host port 5432 사용 중 | Docker host port 변경 또는 기존 DB 중지 |
| 아무것도 없음 | local DB 없거나 미실행 | Docker DB 실습 바로 진행 가능 |

### 삭제 / 중지 / 보류 선택

| 선택 | 언제 | evidence |
|---|---|---|
| 삭제 | 수업용 데이터만 있고 필요 없음 | 삭제 명령, port free 확인 |
| 중지 | 데이터 보존하되 port만 비우고 싶음 | stop 명령, `pg_isready` 실패 확인 |
| 보류 | 삭제/중지가 위험하거나 권한 없음 | 이유 기록, Docker host port를 15432/15433으로 변경 |

삭제는 되돌리기 어렵다. 회사 장비, 개인 프로젝트 DB, 백업 불확실한 경우 보류가 맞다.

### OS별 중지/삭제 절차

**macOS (Homebrew)**
```bash
brew services list | grep postgresql
brew services stop postgresql@16   # 중지
brew uninstall postgresql@16       # 삭제 (데이터 필요 없을 때만)
```

**Linux (Ubuntu)**
```bash
systemctl status postgresql --no-pager
sudo systemctl stop postgresql     # 중지
sudo apt remove postgresql postgresql-*   # 삭제 (데이터 필요 없을 때만)
```

### 공식 postgres image 핵심

- `POSTGRES_PASSWORD` → 필수 환경변수. 없으면 container가 시작되지 않는다.
- `POSTGRES_USER`, `POSTGRES_DB` → 선택값. 지정 안 하면 기본 user는 `postgres`.
- PostgreSQL 16과 18은 volume을 **반드시 따로** 써야 한다.

| 항목 | postgres:16 | postgres:18 |
|---|---|---|
| container port | 5432 | 5432 |
| host port | 15432 | 15433 |
| volume | `paperclip-pg16-data` | `paperclip-pg18-data` |
| user | postgres | postgres |

### 다음 교시 mental model

```
localhost:15432  →  postgres:16 container (내부 port 5432)
localhost:15433  →  postgres:18 container (내부 port 5432)
```

container 내부 port가 둘 다 5432여도 host port가 다르면 동시에 접속 가능하다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
