# 5교시: Failure drill - 출력으로 원인 좁히기

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker run --name paperclip-day4-pg-missing-env postgres:16-alpine` | `POSTGRES_PASSWORD ... must specify` — env 누락으로 시작 실패 (실패 1) |
| `docker run -d --name paperclip-day4-pg-ok -e POSTGRES_PASSWORD=practice-only postgres:16-alpine` | env 주입 후 정상 기동 (실패 1 복구) |
| `docker run --rm --env-file week2/day4/labs/env-report/.env.production alpine:3.20 env` | `open ...: no such file or directory` — env file 경로 오류 (실패 2) |
| `curl -I http://localhost:80` | `curl: (7) Failed to connect to localhost port 80` (실패 3) |
| `curl -I http://localhost:18084` | 정상 응답 — host 18084가 실제 publish된 port (실패 3) |
| `docker ps --filter name=paperclip-day4-nginx` | `0.0.0.0:18084->80/tcp` — host/container 매핑이 첫 증거 (실패 3) |
| `docker network create paperclip-day4-net-a` / `docker network create paperclip-day4-net-b` | 분리된 두 network 생성 (실패 4 준비) |
| `docker run -d --name paperclip-day4-net-web --network paperclip-day4-net-a nginx:1.27-alpine` | nginx를 `net-a`에 띄움 (실패 4 준비) |
| `docker run --rm --network paperclip-day4-net-b alpine:3.20 wget -S -O- http://paperclip-day4-net-web` | `bad address` — 다른 network라 name DNS 실패 (실패 4) |
| `docker run --rm --network paperclip-day4-net-a alpine:3.20 wget -S -O- http://paperclip-day4-net-web \| head` | 정상 응답 — 같은 network면 name으로 접근 가능 (실패 4 복구) |
| `docker run -d --name paperclip-day4-pg-volume -e POSTGRES_PASSWORD=practice-only -e POSTGRES_DB=first -v paperclip-day4-pgdata:/var/lib/postgresql/data postgres:16-alpine` | 최초 init으로 `first` DB 생성 (실패 5 준비) |
| (재생성, `POSTGRES_DB=second`로) `docker run -d --name paperclip-day4-pg-volume ... -e POSTGRES_DB=second -v paperclip-day4-pgdata:... postgres:16-alpine` | 같은 volume 재사용 |
| `docker logs paperclip-day4-pg-volume --tail 30` | `Database directory appears to contain a database; Skipping initialization` — stale volume이 최초 init만 적용 (실패 5) |
| `docker run --rm nginx:no-such-day4-tag` | `pull access denied` / `manifest unknown` — 잘못된 image tag (실패 6) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| failure drill의 핵심은? | 명령부터 고치는 게 아니라 **출력을 읽어 원인을 좁히는 것**이다. 실패를 config / network / port / volume / image로 분류하고, 각 실패의 "첫 확인 명령"을 연결한다. |
| missing env(실패 1)는 어떻게 아는가? | `docker logs`에 `POSTGRES_PASSWORD ... must specify` 같은 명시적 메시지가 뜬다. config 문제이므로 첫 확인은 `docker logs`, 수정은 env 주입이다. |
| wrong env file(실패 2)와 app 문제를 어떻게 구분하나? | `no such file or directory`는 app이 뜨기 **전에** Docker가 env file을 못 찾은 것이다. app 코드 문제가 아니라 경로 문제다. 첫 확인은 `ls`로 파일 존재 확인. |
| wrong port(실패 3)의 첫 증거는? | `docker ps`의 `PORTS`다. `0.0.0.0:18084->80/tcp`는 host 18084 → container 80 매핑을 뜻한다. container 내부 80과 host 80은 다르다. |
| wrong network(실패 4)는 왜 생기나? | container name DNS는 **같은 Docker network 안에서만** 동작한다. 다른 network에 있으면 `bad address`가 난다. 같은 network로 맞추면 name으로 접근된다. |
| stale volume(실패 5)이 위험한 이유는? | env(`POSTGRES_DB`)를 바꿔도 기존 volume에 이미 초기화된 DB가 있으면 `Skipping initialization`으로 **최초 init 설정이 다시 적용되지 않는다.** 설정이 안 먹는 것처럼 보이는 함정이다. |
| bad image tag(실패 6)는 실행 옵션 문제인가? | 아니다. `manifest unknown`은 image reference(tag) 자체가 없는 것이다. 실행 옵션을 아무리 고쳐도 안 되고, `docker image ls`로 tag를 확인해야 한다. |
| 수정 전에 먼저 던질 질문은? | "이 실패가 config/network/port/volume/image 중 어디인가", "첫 증거 명령은 무엇인가", "출력의 어느 줄이 힌트인가", "수정하면 data가 지워지나"를 먼저 채운다. |

## notes

### failure drill의 기본자세 — 명령보다 출력 먼저

실패를 만나면 명령을 바꿔 다시 시도하기 전에 **출력을 읽어 원인 범주를 좁힌다.** 6가지 실패는 모두 출력에 서로 다른 지문(signature)을 남긴다.

### 6가지 실패 RCA 표

| 실패 | 대표 출력 | 첫 확인 명령 | 수정 방향 | 범주 |
|---|---|---|---|---|
| missing env | `POSTGRES_PASSWORD` | `docker logs` | env 주입 | config |
| wrong env file | `no such file or directory` | `ls`, `pwd` | env file 경로 수정 | config |
| wrong port | `Failed to connect`, `18084->80` | `docker ps` | host port 수정 | network/port |
| wrong network | `bad address` | `docker network inspect` | 같은 network 사용 | network |
| stale volume | `Skipping initialization` | `docker logs`, `volume inspect` | reset 여부 판단 | volume/state |
| bad image tag | `manifest unknown` | `docker image ls` | tag 확인 | image |

### 각 실패의 핵심 감각

| 실패 | 헷갈리기 쉬운 점 | 잡아야 할 기준 |
|---|---|---|
| missing env | "왜 안 뜨지"로 막연히 봄 | logs가 `POSTGRES_PASSWORD`라고 직접 말해준다. 메시지를 읽으면 끝 |
| wrong env file | app 버그로 오해 | app이 뜨기 **전** 단계의 경로 오류. `ls`로 파일부터 확인 |
| wrong port | container 80 = host 80으로 착각 | `docker ps`의 `PORTS`가 진짜 매핑(`host->container`) |
| wrong network | "이름 붙였는데 왜 안 찾지" | name DNS는 **같은 network 안에서만**. network를 맞춘다 |
| stale volume | env 바꿨는데 왜 그대로지 | volume에 남은 init된 DB가 우선. `Skipping initialization`이 증거 |
| bad image tag | 실행 옵션을 계속 고침 | image reference 문제. 옵션이 아니라 tag를 본다 |

### 특히 stale volume — data 삭제 위험과 직결

실패 5는 단순 오류가 아니라 **data가 살아있다는 증거**다. env(`POSTGRES_DB=second`)를 바꿔도 기존 volume에 `first` DB가 그대로 있으면 postgres는 재초기화하지 않고 `Skipping initialization`을 찍는다. "설정이 안 먹는다"고 volume을 지워버리면 **실제 데이터가 사라진다.** 그래서 stale volume은 항상 "수정하면 data가 삭제되는가"를 먼저 묻는다(6교시 cleanup·data 삭제 판단으로 연결).

### stale volume을 어떻게 해결하나 — 지우는 게 답이 아니다

`Skipping initialization`은 **고쳐야 할 에러가 아니라 판단해야 할 신호**다. 보자마자 "volume을 지워야지"가 되면 위험하다. 먼저 물을 것은 **"이 데이터가 내가 지켜야 할 데이터인가?"** 다.

```text
Skipping initialization 발견
        │
        ▼
  이 volume의 data가 필요한가?
   ┌────┴─────────┐
  필요함        버려도 됨
   │              │
   ▼              ▼
volume 유지   확인→백업→reset
(지우면 안 됨)
```

**① data가 필요한 경우 — volume을 지우는 게 아니라 살아있는 DB를 다룬다.** 이건 정상 동작이다(volume이 영속 역할을 제대로 함). 새 설정을 반영하려면 재초기화가 아니라 실행 중 DB에 직접 적용한다.

```bash
docker exec -it paperclip-day4-pg-volume psql -U postgres -c "CREATE DATABASE second;"
```

스키마 변경이면 init 스크립트(최초 1회만 실행)가 아니라 **migration**(Flyway, Alembic 등)으로 적용한다.

**② 정말 fresh start가 필요한 경우 — 바로 지우지 않고 절차를 밟는다.**

```bash
docker volume inspect paperclip-day4-pgdata # 1. 뭐가 들어있고 누가 쓰는지 확인
docker ps -a --filter volume=paperclip-day4-pgdata
docker exec paperclip-day4-pg-volume pg_dumpall -U postgres > backup.sql # 2. 필요하면 백업
docker rm -f paperclip-day4-pg-volume # 3. 그 다음에 reset
docker volume rm paperclip-day4-pgdata
```

| 상황 | 올바른 대응 |
|---|---|
| data를 지켜야 함 | volume 유지. 변경은 실행 중 DB에 `psql`/migration으로 |
| data 버려도 됨 | inspect로 확인 → 필요 시 백업 → 그 다음 삭제 |
| **어느 쪽인지 모름** | **모르면 일단 지우지 않는다.** 삭제는 복구 불가 |

"volume 함부로 지우지 마라"의 진짜 의미는 **"지우기 전에 그게 뭔지 확인하고, 필요하면 백업하라"** 다. 그래서 RCA 표의 수정 방향도 `삭제`가 아니라 **`reset 여부 판단`** 이다(6교시 cleanup·data 삭제 판단으로 연결).

### 제출 전 판단 질문

명령을 고치기 전에 먼저 채운다.

| 질문 | 왜 중요한가 |
|---|---|
| config / network / port / volume / image 중 어디인가 | 범주를 정해야 첫 확인 명령이 정해진다 |
| 첫 번째 증거 명령은 무엇인가 | 추측이 아니라 출력으로 시작한다 |
| 출력의 어느 줄이 원인 힌트인가 | 전체가 아니라 결정적 한 줄을 짚는다 |
| 수정하면 data가 삭제되는가 | 특히 volume 관련은 복구 불가일 수 있다 |
| Compose/Kubernetes면 어떤 리소스를 볼 것인가 | 같은 원인이 도구가 바뀌어도 이어진다 |

### 흔한 오해

- 실패하면 명령부터 바꿔본다 → 출력을 먼저 읽어 범주를 좁힌다. 추측 재시도는 시간만 쓴다.
- container 포트 80이면 host도 80 → `docker ps`의 `host->container` 매핑을 본다.
- 이름 붙였으니 어디서든 찾는다 → name DNS는 같은 network 한정.
- 설정이 안 먹으면 volume을 지운다 → stale volume일 뿐, 지우면 data가 날아간다. 먼저 `volume inspect`/logs.
- 안 되면 실행 옵션을 계속 고친다 → `manifest unknown`은 옵션이 아니라 tag 문제다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
