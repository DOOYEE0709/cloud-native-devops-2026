# 6교시: Cleanup과 security audit

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker ps -a --filter name=paperclip-day4` | day4 실습으로 남은 container 목록 확인 (nginx, pg-ok, crash 등) |
| `docker network ls \| grep paperclip-day4` | 남은 임시 network(`net-a`, `net-b`) 확인 |
| `docker volume ls \| grep paperclip-day4` | 남은 volume(`paperclip-day4-pgdata`) 확인 |
| `docker system df` | image/container/volume/cache가 차지한 용량 확인 |
| `docker rm -f paperclip-day4-nginx ... paperclip-day4-pg-volume` | 실패·임시 container 일괄 삭제 |
| `docker network rm paperclip-day4-net-a paperclip-day4-net-b` | 임시 network 삭제 |
| `rm -f .../.env .../.env.dev .../.env.staging .../.env.prod` | 로컬 실습 env 산출물 삭제 (`.env.example`은 유지) |
| (판단 후) `docker volume rm paperclip-day4-pgdata` | DB data 삭제 — 보존 불필요할 때만 명시적 판단 후 실행 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| cleanup은 "다 지우기"인가? | 아니다. 대상마다 의미가 다르다. container 삭제는 process와 writable layer 제거, image 삭제는 다음에 재pull/build 필요, network 삭제는 연결 공간 제거, **volume 삭제는 data 삭제**일 수 있다. |
| 장애 드릴 뒤 왜 정리해야 하나? | 실패 container와 임시 network를 안 치우면 다음 수업에서 이름 충돌, port 충돌, stale volume 혼동이 생긴다. |
| container/image/network/volume 중 삭제가 가장 위험한 건? | named volume이다. DB data처럼 복구 불가한 내용이 들어있을 수 있다. container·임시 network는 비교적 안전하게 지운다. |
| env file은 어떻게 처리하나? | `.env`, `.env.dev/staging/prod`처럼 실제 값이 들어갈 수 있는 로컬 산출물은 삭제(또는 local 보관)한다. `.env.example`은 공유용 형식 문서라 **유지**한다. |
| `docker system prune --volumes`를 써도 되나? | 안 된다. volume까지 포함한 prune은 실습 DB data나 **다른 프로젝트 data까지** 삭제할 수 있다. 이 명령은 쓰지 않는다. |
| `docker volume rm paperclip-day4-pgdata`는 언제 쓰나? | stale volume을 reset해야 하고 그 data가 보존 대상이 아닐 때만, 명시적으로 판단한 뒤 실행한다. 보존해야 하는 data면 실행하지 않는다(5교시 연결). |
| security audit에서 무엇을 점검하나? | secret이 `.env`·image·repository·로그·screenshot에 흔적으로 남지 않았는지, 공유 산출물에 실제 값이 섞이지 않았는지 점검한다. |

## notes

### cleanup은 "다 지우기"가 아니다 — 대상마다 의미가 다르다

| 대상 | 삭제하면 일어나는 일 | 위험도 |
|---|---|---|
| container | 실행 process + writable layer 제거 | 낮음 (image로 재생성) |
| image | 다음 실행 때 재pull/build 필요 | 낮음 (다시 받으면 됨) |
| network | 연결 공간 제거 | 낮음 (재생성 가능) |
| **named volume** | **data 삭제일 수 있음** | **높음 (복구 불가)** |

핵심: container/image/network는 다시 만들 수 있지만, volume은 한 번 지우면 안의 data가 사라진다. cleanup은 "무엇을 지우는가"가 아니라 **"이걸 지우면 무엇이 사라지는가"** 로 판단한다.

### 삭제 판단 표

| 대상 | 기본 판단 | 이유 |
|---|---|---|
| 실패 container | 삭제 | 다음 실습 이름 충돌 방지 |
| 임시 network | 삭제 | 실습 전용 연결 공간 |
| `.env` | 삭제 또는 local 보관 | 실제 값 노출 방지 |
| `.env.dev/staging/prod` | 실습 파일이면 삭제 | 환경별 secret 혼동 방지 |
| `.env.example` | 유지 | 공유용 형식 문서 |
| image | 보통 유지 | 다음 실습에서 재사용 가능 |
| named volume | 신중히 판단 | DB data 삭제 가능 |

### audit → cleanup 순서

지우기 전에 **무엇이 남았는지 먼저 본다.** 추측으로 지우지 않는다.

```text
1. docker ps -a --filter name=...   → 남은 container
2. docker network ls | grep ...     → 남은 network
3. docker volume ls | grep ...      → 남은 volume
4. docker system df                 → 용량 점유 현황
   ↓ 목록을 보고 삭제 판단표에 대입
5. docker rm -f ... / network rm ... → 안전한 것부터 삭제
6. volume은 별도 판단 후에만
```

### 위험한 명령 — `prune --volumes`는 쓰지 않는다

```bash
docker system prune --volumes   # 사용 금지
```

volume까지 포함한 prune은 실습 DB data뿐 아니라 **다른 프로젝트의 data까지** 한 번에 삭제할 수 있다. "안 쓰는 것 정리"처럼 보이지만 범위가 너무 넓다. volume 삭제는 항상 **이름을 지정해서** 명시적으로 한다.

```bash
docker volume rm paperclip-day4-pgdata   # 이 data가 보존 대상이 아닐 때만
```

이 명령은 PostgreSQL data를 삭제한다. stale volume reset에는 유용하지만, 보존해야 하는 data라면 실행하면 안 된다(5교시 "지우는 게 답이 아니다" 연결).

### security audit — secret 흔적 점검

cleanup은 자원 정리이자 **secret 흔적 점검**의 기회다. Day 4 내내 다룬 기준을 마지막에 한 번 더 확인한다.

| 점검 항목 | 기준 |
|---|---|
| `.env`에 실제 값이 남았나 | 로컬 산출물이면 삭제. repository에 올라가지 않게 |
| 공유 파일에 secret이 섞였나 | `.env.example`엔 placeholder만, 실제 값 금지 |
| 로그·screenshot에 평문 secret이 있나 | 있으면 masking이 아니라 revoke/rotate (1·2교시) |
| image layer에 secret이 들어갔나 | build context에 `.env`·token이 안 들어갔는지 |

핵심: **`.env.example`은 남기고(형식 문서), 실제 값이 든 산출물은 지운다.** 노출이 의심되는 credential은 가리는 게 아니라 폐기·교체한다.

### 흔한 오해

- cleanup = 전부 삭제 → 대상마다 의미가 다르다. volume만 위험도가 다르다.
- `prune --volumes`로 깔끔하게 정리 → 다른 프로젝트 data까지 날아갈 수 있다. 금지.
- `.env.example`도 지워야 안전 → 형식 문서라 유지한다. 지울 건 실제 값이 든 `.env` 계열.
- container 지웠으니 secret도 사라졌다 → image layer·repository·로그에 남았을 수 있다. 별도 점검.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
