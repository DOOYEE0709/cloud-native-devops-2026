# 7교시: PostgreSQL 16/18 컨테이너 병렬 실행

## 실습 확인 기록

| 명령/확인 | 설명 | 결과 |
|---|---|---|
| `docker run -d --name paperclip-pg16 -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=paperclip -p 15432:5432 -v paperclip-pg16-data:/var/lib/postgresql/data postgres:16` | postgres:16 container 실행 | ![docker run pg16](assets\lesson-07\docker-run-pg16.png) |
| `docker ps --filter name=paperclip-pg16` | pg16 실행 상태와 port binding 확인 | ![docker ps filter pg16](assets\lesson-07\docker-ps-pg16.png) |
| `docker logs paperclip-pg16` | pg16 DB 초기화 완료 메시지 확인 | ![docker logs pg16](assets\lesson-07\docker-logs-pg16.png) |
| `docker run -d --name paperclip-pg18 -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=paperclip -p 15433:5432 -v paperclip-pg18-data:/var/lib/postgresql postgres:18` | postgres:18 container 실행 | ![docker run pg18](assets\lesson-07\docker-run-pg18.png) |
| `docker ps --filter name=paperclip-pg18` | pg18 실행 상태와 port binding 확인 | ![docker ps filter pg18](assets\lesson-07\docker-ps-pg18.png) |
| `docker logs paperclip-pg18` | pg18 DB 초기화 완료 메시지 확인 | ![docker logs pg18](assets\lesson-07\docker-logs-pg18.png) |
| `docker exec paperclip-pg16 psql -U postgres -d paperclip -c "SELECT version();"` | pg16 버전 쿼리 — Docker daemon 접근 가능할 때 | ![docker exec pg16 version](assets\lesson-07\exec-pg16-version.png) |
| `docker exec paperclip-pg18 psql -U postgres -d paperclip -c "SELECT version();"` | pg18 버전 쿼리 — Docker daemon 접근 가능할 때 | ![docker exec pg18 version](assets\lesson-07\exec-pg18-version.png) |
| `PGPASSWORD=postgres psql -h localhost -p 15432 -U postgres -d paperclip -c "SELECT version();"` | pg16 버전 쿼리 — host psql client로 접속 | ![psql pg16 version](assets\lesson-07\psql-pg16-version.png) |
| `PGPASSWORD=postgres psql -h localhost -p 15433 -U postgres -d paperclip -c "SELECT version();"` | pg18 버전 쿼리 — host psql client로 접속 | ![psql pg18 version](assets\lesson-07\psql-pg18-version.png) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 두 container의 container port가 둘 다 5432인데 동시에 실행 가능한가? | 가능하다. container 내부 5432는 각 container 안에서 독립적이다. host port를 15432, 15433으로 다르게 publish했기 때문에 충돌이 없다. |
| `docker ps`에서 container 상태가 `Up`이면 DB에 바로 접속 가능한가? | 아니다. container가 Up이어도 DB 초기화가 진행 중일 수 있다. `docker logs`에서 `database system is ready to accept connections` 메시지가 나온 후 접속해야 한다. |
| host에 `psql`이 없어도 version 확인을 할 수 있는가? | 가능하다. `docker exec`로 container 안의 `psql`을 쓰면 된다. host에 client가 없어도 실습에 지장이 없다. |
| postgres:16과 postgres:18의 volume path가 왜 다른가? | postgres:18은 공식 image의 `PGDATA` 기본 경로가 바뀌었다. 16은 `/var/lib/postgresql/data`, 18은 `/var/lib/postgresql`까지만 지정한다. version별로 volume을 따로 써야 데이터가 섞이지 않는다. |
| 같은 `POSTGRES_PASSWORD`를 쓰면 같은 DB 인스턴스가 되는가? | 아니다. container, volume, port가 다르면 완전히 별개의 DB 인스턴스다. password가 같다는 것은 각 DB 안의 계정 설정이 같다는 뜻이다. |

## notes

### 실습 전 기존 container 확인

```bash
docker ps -a --filter name=paperclip-pg
```

헤더만 나오면 진행 가능. 같은 이름의 container가 보이면 먼저 정리한다.

```bash
docker stop paperclip-pg16 paperclip-pg18
docker rm paperclip-pg16 paperclip-pg18
```

`No such container` error는 정리 대상이 없다는 뜻이므로 무시해도 된다.

### docker run 옵션 읽는 법

```bash
docker run -d \
  --name paperclip-pg16 \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=paperclip \
  -p 15432:5432 \
  -v paperclip-pg16-data:/var/lib/postgresql/data \
  postgres:16
```

| 옵션 | 의미 |
|---|---|
| `-d` | 백그라운드 실행 |
| `--name paperclip-pg16` | container 이름 지정 (lifecycle 관리용) |
| `-e POSTGRES_PASSWORD=postgres` | 필수 환경변수. 없으면 container가 시작되지 않는다 |
| `-e POSTGRES_DB=paperclip` | 초기 DB 이름 지정 |
| `-p 15432:5432` | host 15432 → container 5432 포워딩 |
| `-v paperclip-pg16-data:/var/lib/postgresql/data` | named volume으로 데이터 영속화 |
| `postgres:16` | 사용할 image와 tag |

### version별 volume 경로 차이

| | postgres:16 | postgres:18 |
|---|---|---|
| volume mount target | `/var/lib/postgresql/data` | `/var/lib/postgresql` |
| host port | 15432 | 15433 |
| container 이름 | `paperclip-pg16` | `paperclip-pg18` |
| volume 이름 | `paperclip-pg16-data` | `paperclip-pg18-data` |

volume을 절대 공유하지 않는다. major version이 다르면 데이터 포맷이 달라 공유하면 깨진다.

### `docker ps` 정상 출력 확인

```text
NAME            PORTS
paperclip-pg16  0.0.0.0:15432->5432/tcp
paperclip-pg18  0.0.0.0:15433->5432/tcp
```

- 왼쪽 숫자(15432, 15433) = psql로 접속하는 host port
- 오른쪽 숫자(5432) = container 내부 PostgreSQL이 듣는 port

### `docker logs` 정상 확인 기준

```text
LOG:  database system is ready to accept connections
```

이 메시지가 나오기 전에 접속하면 `Connection refused`가 날 수 있다. `docker logs`에서 확인 후 접속한다.

### version 쿼리 방법 두 가지 — `docker exec` vs host psql

| | `docker exec` | host psql client |
|---|---|---|
| 접근 조건 | **Docker daemon에 접근 가능해야 한다** | DB port(15432/15433)만 열려 있으면 된다 |
| 실무에서 누가 쓰나 | 서버에 직접 붙어 있는 DevOps/SRE | 개발자, DBA — 원격 접속 |
| 필요한 것 | docker CLI, daemon 권한 | psql client 설치 |
| 비유 | 주방에 직접 들어가서 요리사한테 말하는 것 | 홀에서 메뉴를 주문하는 것 |

`docker exec`는 Docker daemon이 있는 서버 내부 사람만 쓸 수 있다. 개발자가 원격에서 DB에 접속하려면 Docker를 몰라도 되는 psql client가 필요하다. 그래서 psql client를 따로 설치한 것이다.

**host psql client로 접속 (Docker daemon 없이)**
```bash
PGPASSWORD=postgres psql -h localhost -p 15432 -U postgres -d paperclip -c "SELECT version();"
PGPASSWORD=postgres psql -h localhost -p 15433 -U postgres -d paperclip -c "SELECT version();"
```

**docker exec로 접속 (daemon 접근 가능할 때)**
```bash
docker exec paperclip-pg16 psql -U postgres -d paperclip -c "SELECT version();"
docker exec paperclip-pg18 psql -U postgres -d paperclip -c "SELECT version();"
```

최종 evidence 기준: "container가 Running이다"가 아니라 **"15432는 16 계열, 15433은 18 계열 version을 반환했다"** 가 evidence다.

| 접속 | 기대 결과 |
|---|---|
| `localhost:15432` | `PostgreSQL 16.x ...` 출력 |
| `localhost:15433` | `PostgreSQL 18.x ...` 출력 |

### DB version 업그레이드의 어려움

Docker로 버전을 쉽게 바꿔 실행할 수 있지만, **실제 데이터가 들어간 DB의 major version 업그레이드는 쉽지 않다.**

- major version 업그레이드는 한 단계씩 올려야 하고 각 단계마다 마이그레이션 + 검증이 필요하다. (예: 14 → 16 → 18)
- 롤백이 어렵다. 데이터 포맷이 바뀌면 낮은 버전으로 내려가는 게 거의 불가능하다.
- Kubernetes 환경도 예외가 없다. StatefulSet으로 관리하더라도 DB version 업그레이드는 별도 절차가 필요하다.

오늘 실습에서 16과 18을 **병렬로 띄운 이유**가 여기 있다. 마이그레이션 전에 새 version과 기존 version을 동시에 올려두고 데이터를 옮기면서 검증하는 방식이 실무에서도 쓰인다.

### 개발 환경 DB를 내부(로컬)에서 운영하는 이유

cloud DB (RDS, Cloud SQL 등)는 항상 비용이 발생한다. 개발 단계에서는 비용 절감을 위해 DB를 외부 클라우드가 아니라 **로컬 또는 사내 서버에서 직접 운영**하는 경우가 많다.

| 환경 | DB 운영 방식 | 이유 |
|---|---|---|
| 개발(dev) | 로컬 Docker container | 비용 없음, 빠른 초기화 가능 |
| 스테이징(staging) | 사내 서버 또는 소형 cloud DB | 비용 절감, 프로덕션 유사 환경 |
| 프로덕션(prod) | cloud managed DB (RDS 등) | 안정성, 백업, HA 자동화 |

오늘 실습이 dev 단계에서 Docker로 DB를 로컬에 띄우는 패턴이다.

### DB 스케일링 — 업스케일만 되는 이유

API 서버 같은 **stateless 서비스**는 인스턴스를 여러 개 추가하는 수평 확장(scale out)이 쉽다. 요청이 어느 인스턴스로 가도 결과가 같기 때문이다.

**DB는 stateful 서비스다.** 데이터가 어디에 있는지가 중요하다.

| 방식 | 설명 | DB에서 가능 여부 |
|---|---|---|
| Scale Up (수직 확장) | 서버를 더 큰 것으로 교체 (CPU/메모리 증가) | 가능 |
| Scale Out (수평 확장) | 서버 인스턴스를 여러 개로 늘림 | 쓰기(Write)는 거의 불가능. 읽기(Read)는 Read Replica로 가능 |

- **Write scaling**이 어려운 이유: 여러 인스턴스가 동시에 쓰면 어느 게 최신 데이터인지 결정해야 한다 (데이터 정합성 문제).
- 실무에서 DB는 기본적으로 **scale up**으로 버티고, 읽기 부하가 크면 **Read Replica**를 추가한다.
- Sharding 같은 write 수평 확장도 있지만 구조 자체를 처음부터 다르게 설계해야 해서 나중에 적용하기 매우 어렵다.

### DB timezone — UTC로 두는 이유

**옛날 방식**: DB timezone을 KST(한국 시간, UTC+9)로 직접 설정했다.

**요즘 방식**: DB는 UTC 그대로 두고, 애플리케이션에서 KST로 변환한다.

**이유**: DB를 KST로 설정해두고 서버를 재시작(restart)하면, 재시작 이후 들어온 데이터가 UTC로 찍히는 경우가 생긴다. 그러면 재시작 전 데이터(KST)와 이후 데이터(UTC) 사이에 9시간 차이가 발생해 데이터 정합성이 깨진다.

```
재시작 전 데이터: 2026-06-17 14:00:00  ← KST로 저장됨
재시작 후 데이터: 2026-06-17 05:00:00  ← UTC로 저장됨 (같은 시각인데 9시간 차이처럼 보임)
```

| 방식 | DB timezone | 표시 전환 | 위험 |
|---|---|---|---|
| 옛날 | KST 직접 설정 | DB가 처리 | restart 후 timezone 초기화 시 데이터 꼬임 |
| 요즘 | UTC 유지 | 애플리케이션이 처리 | 없음 — 저장 기준이 항상 UTC로 일관 |

오늘 실습 container(`postgres:16`, `postgres:18`)도 별도 설정 없으면 UTC다. 그대로 두는 게 맞다.

### 흔한 오해

- 두 container가 같은 PostgreSQL이라 동시에 못 띄운다 → container 이름, volume, host port를 다르게 하면 동시에 실행할 수 있다.
- container port도 15432, 15433으로 바꿔야 한다 → container 내부 PostgreSQL은 계속 5432를 쓴다. host port만 다르게 publish한다.
- `docker ps`에서 `Up`이면 바로 접속 가능하다 → DB 초기화 완료 메시지를 `docker logs`에서 확인 후 접속한다.
- 16과 18 volume을 공유해도 된다 → major version별로 PGDATA 경로와 데이터 포맷이 달라 공유하면 데이터가 깨질 수 있다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
