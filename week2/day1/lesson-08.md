# 8교시: 포트 충돌, 정리, 증거 제출

## 실습 확인 기록

| 명령/확인 | 설명 | 결과 |
|---|---|---|
| `docker run -d --name paperclip-pg18-conflict -e POSTGRES_PASSWORD=postgres -p 15432:5432 postgres:18` | 같은 host port 15432로 pg18 실행 시도 (의도적 충돌) | ![port conflict](assets\lesson-08\port-conflict.png) |
| `docker rm paperclip-pg18-conflict` | 충돌로 생성된 container 정리 | ![docker rm conflict](assets\lesson-08\docker-rm-conflict.png) |
| `docker ps --filter name=paperclip-pg` | 정상 상태 재확인 (pg16/pg18 모두 실행 중) | ![docker ps pg](assets\lesson-08\docker-ps-pg.png) |
| `PGPASSWORD=postgres psql -h localhost -p 15432 -U postgres -d paperclip -c "SELECT version();"` | pg16 최종 version 확인 | ![psql pg16 final](assets\lesson-08\psql-pg16-final.png) |
| `PGPASSWORD=postgres psql -h localhost -p 15433 -U postgres -d paperclip -c "SELECT version();"` | pg18 최종 version 확인 | ![psql pg18 final](assets\lesson-08\psql-pg18-final.png) |
| `docker stop paperclip-pg16 paperclip-pg18` | container 중지 | ![docker stop](assets\lesson-08\docker-stop.png) |
| `docker rm paperclip-pg16 paperclip-pg18` | container 삭제 | ![docker rm](assets\lesson-08\docker-rm.png) |
| `docker volume rm paperclip-pg16-data paperclip-pg18-data` | 실습 volume 삭제 | ![docker volume rm](assets\lesson-08\docker-volume-rm.png) |
| `docker ps -a --filter name=paperclip-pg` | container 정리 완료 확인 | ![docker ps -a final](assets\lesson-08\docker-ps-a-final.png) |
| `docker volume ls \| grep paperclip-pg` | volume 정리 완료 확인 | ![docker volume ls](assets\lesson-08\docker-volume-ls.png) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 왜 같은 host port를 두 container가 동시에 사용할 수 없는가? | host port는 host machine의 network 자원이다. 같은 IP/port 조합은 한 번에 하나만 점유할 수 있다. container 내부 port(5432)는 각 container namespace 안에서 독립적이라 같아도 되지만, host port는 공유할 수 없다. |
| container를 삭제하면 DB 데이터도 사라지는가? | named volume에 저장한 데이터는 container 삭제 후에도 남는다. `docker volume rm`까지 해야 데이터가 삭제된다. |
| port conflict error 문구가 강사 화면과 다른데 실패가 맞는가? | 맞다. `port is already allocated`, `Bind for ... failed`, `address already in use` 등 Docker version과 OS에 따라 표현이 다르다. "같은 host port를 이미 사용 중"이라는 원인이 맞으면 정상 실패다. |
| volume을 삭제하면 되돌릴 수 있는가? | 없다. `docker volume rm`은 데이터를 영구 삭제한다. 개인 DB나 다른 수업 산출물이 연결된 volume에는 실행하지 않는다. |

## notes

### 의도적 port 충돌 실험

pg16이 `15432:5432`로 실행 중인 상태에서 pg18도 같은 host port `15432`로 실행 시도:

```bash
docker run -d \
  --name paperclip-pg18-conflict \
  -e POSTGRES_PASSWORD=postgres \
  -p 15432:5432 \
  postgres:18
```

기대되는 실패 메시지:
```text
Bind for 0.0.0.0:15432 failed: port is already allocated
```

문구는 환경마다 다를 수 있다. 핵심 원인: **host port 15432를 이미 paperclip-pg16이 점유 중**이라 두 번째 container가 publish 불가.

port conflict가 나면 container는 실행(Running)되지 않지만 **Created 상태로 남아 있다.** `docker ps`에는 보이지 않고 `docker ps -a`에서 확인할 수 있다. 그대로 두면 같은 이름(`paperclip-pg18-conflict`)으로 다시 실행하려 할 때 포트 충돌이 나므로 반드시 `docker rm`으로 정리해야 한다.

```bash
docker ps -a --filter name=paperclip-pg18-conflict   # Created 상태 확인
docker rm paperclip-pg18-conflict                    # 정리
```

| 구분 | pg16 | pg18 (정상) | pg18 (충돌) |
|---|---|---|---|
| container port | 5432 | 5432 | 5432 |
| host port | 15432 | 15433 | 15432 (충돌) |
| 결과 | 실행 가능 | 실행 가능 | publish 실패 |

### container vs volume cleanup 구분

| 선택 | 명령 | 결과 |
|---|---|---|
| container만 정리 | `docker stop` + `docker rm` | process 종료, named volume 데이터는 남음 |
| 데이터까지 정리 | 위 + `docker volume rm` | volume 데이터까지 완전 삭제 |

```bash
docker stop paperclip-pg16 paperclip-pg18
docker rm paperclip-pg16 paperclip-pg18
docker volume rm paperclip-pg16-data paperclip-pg18-data
```

정리 후 확인:
```bash
docker ps -a --filter name=paperclip-pg
docker volume ls | grep paperclip-pg
```

둘 다 헤더만 나오면 완전 정리 완료.

### volume 이름을 지정해서 만들어야 하는 이유

volume을 만들 때 이름을 지정하지 않으면 Docker가 랜덤 hash를 ID로 붙인다.

```text
VOLUME NAME
a3f9c2e1b7d4...   ← 이게 어떤 container 데이터인지 알 수 없다
paperclip-pg16-data  ← 이름만 봐도 어느 container 데이터인지 알 수 있다
```

이름 없는 volume(익명 volume)이 쌓이면 `docker volume ls`에서 어느 게 어떤 container 데이터인지 구분할 수 없어서 잘못 삭제하거나 방치하게 된다. 정리할 때도 `docker volume rm`에 이름을 직접 써야 하는데, hash로는 실수하기 쉽다.

```bash
# 이름 지정 (권장)
-v paperclip-pg16-data:/var/lib/postgresql/data

# 이름 없음 (비권장) — Docker가 hash ID를 붙임
-v /var/lib/postgresql/data
```

### Day 1 마감 evidence 양식

```
## Week 2 Day 1 Final Evidence
- Docker install path:
- docker version summary:
- docker compose version summary:
- hello-world result:
- Local PostgreSQL cleanup decision:
- pg16 host port / version query result:
- pg18 host port / version query result:
- port conflict error summary:
- cleanup result:
- remaining blocker:
```

### Day 2 연결

오늘은 공식 image(`postgres:16`, `postgres:18`, `nginx`)를 pull해서 실행했다. Day 2부터는 실행 조건을 직접 **Dockerfile**로 고정해서 image를 직접 build한다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
