# 2교시: Logs와 HTTP 정상 확인

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker run -d --name paperclip-day4-nginx -p 18084:80 nginx:1.27-alpine` | nginx container 백그라운드 실행 |
| `docker ps --filter name=paperclip-day4-nginx` | `STATUS Up`, `0.0.0.0:18084->80/tcp` 확인 |
| `curl -I http://localhost:18084` | `HTTP/1.1 200 OK` |
| `docker logs paperclip-day4-nginx --tail 30` | startup 로그 + `curl` 이후 access log 확인 |
| `docker run -d --name paperclip-day4-api -p 18088:8080 -e RESPONSE_MODE=text ... python app.py` | text mode로 backend 실행 (의도된 잘못된 상태) |
| `curl -i http://localhost:18088/health` | `HTTP/1.0 200 OK` + body `OK` |
| `curl -i http://localhost:18088/api/items` (text mode) | `HTTP/1.0 200 OK`인데 body가 `OK` (JSON 아님) |
| 브라우저 `http://localhost:18087/items.html` (text mode) | 200인데도 JSON parse failed 표시 |
| `docker rm -f paperclip-day4-api` 후 `docker run -d --name paperclip-day4-api -p 18088:8080 -e RESPONSE_MODE=json ... python app.py` | backend를 json mode로 재생성 |
| `curl -i http://localhost:18088/api/items` (json mode) | `/api/items`가 `Content-Type: application/json` + `{"items": ...}` 반환 |
| `items.html` 새로고침 (json mode) | list 정상 렌더링 |
| `docker run --name paperclip-day4-log-env --env-file ... /work/report.sh` | `DB_PASSWORD=***masked***`로 로그 출력 확인 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| `docker ps`의 `Up`은 서비스 정상을 뜻하는가? | 아니다. `Up`은 process가 살아 있다는 뜻이다. 사용자가 접속 가능한지, port가 맞는지, app이 정상 응답하는지는 `curl`과 logs로 따로 확인해야 한다. |
| HTTP 200이면 정상인가? | 항상은 아니다. status code가 200이어도 body 형식이 frontend가 기대하는 계약(JSON 등)과 다르면 사용자 화면은 실패한다. status, body type, JSON schema, rendering을 함께 봐야 한다. |
| 같은 200인데 `ok.html`은 정상이고 `items.html`은 실패한 이유는? | `ok.html`은 200과 `OK` body만 보면 충분하다. `items.html`은 `/api/items` body를 `response.json()`으로 파싱하는데, text mode가 돌려준 `OK`는 JSON이 아니라 parse error가 난다. |
| backend log에 요청이 찍혔으면 정상인가? | request가 도달했다는 증거일 뿐이다. 응답 schema가 frontend 계약과 맞는지는 별도다. 화면 성공을 보장하지 않는다. |
| logs가 비어 있으면 장애인가? | 항상은 아니다. 아직 요청을 안 보냈거나 image가 startup log를 적게 남길 수 있다. `curl`을 먼저 보내고 logs를 다시 본다. |
| logs에 env를 남길 때 기준은? | `APP_ENV=staging` 같은 환경 이름은 도움이 된다. 하지만 `DB_PASSWORD`, `AWS_SECRET_ACCESS_KEY` 같은 실제 secret을 찍으면 실패다. 로그가 유출 경로가 된다. |
| text mode를 json mode로 바꾸려면? | container를 다시 만들어야 한다. `docker rm -f` 후 `-e RESPONSE_MODE=json`으로 재실행한다. 기존 container의 env는 바뀌지 않는다. |

## notes

### `Up`과 서비스 정상은 다르다

container가 `Up`이면 process가 살아 있다는 뜻이지, 사용자가 접근 가능한 정상 상태라는 뜻이 아니다. 확인 단계를 나눠서 본다.

| 확인 기준 | 정상처럼 보이는 증거 | 놓칠 수 있는 문제 |
|---|---|---|
| process | `docker ps`에서 `Up` | 요청을 처리하지 못할 수 있음 |
| HTTP status | `HTTP/1.1 200 OK` | body 형식이 frontend 계약과 다를 수 있음 |
| backend log | 요청이 도착함 | 응답 schema가 잘못됐을 수 있음 |
| frontend rendering | JSON list가 화면에 보임 | 실제 사용자 기능 정상 여부를 확인 |

### 200 OK의 함정 — JSON contract

backend가 `/health`(plain text `OK`)와 `/api/items`(JSON list) 두 endpoint를 가질 때, frontend는 `/api/items`를 `response.json()`으로 파싱한다.

- `RESPONSE_MODE=text` → `/api/items`도 200을 돌려주지만 body가 `OK`다. status만 보면 정상, 화면은 JSON parse failed.
- `RESPONSE_MODE=json` → `Content-Type: application/json` + `{"items": ...}`. list가 정상 렌더링된다.

핵심: **HTTP 200과 frontend parsing 성공은 다른 정상 기준이다.** backend process와 status code만 보면 정상처럼 보여도 사용자 기능은 실패할 수 있다.

### 상태 판단 표

| 관찰 | backend 관점 | frontend/사용자 관점 | 판단 |
|---|---|---|---|
| `/health` 200 OK | process와 route는 살아 있음 | health page는 정상 | 부분 정상 |
| `/api/items` 200 + `OK` | 요청 처리 성공처럼 보임 | JSON parse failed | 서비스 비정상 |
| `/api/items` 200 + JSON list | API 계약 충족 | list 렌더링 성공 | 정상 |
| backend log에 요청 있음 | request 도달 확인 | 화면 성공 보장은 아님 | 추가 확인 필요 |

### logs에 뭐가 찍히는지는 프로그램이 정한다

`docker logs`는 그 안에서 실행된 프로그램이 stdout/stderr에 찍은 것을 그대로 보여줄 뿐이다. 무엇을 남길지는 Docker가 아니라 프로그램이 결정한다.

| container | 실행한 것 | 하는 일 | logs에 보이는 것 |
|---|---|---|---|
| `paperclip-day4-log-env` | `report.sh` | env를 출력하는 스크립트 | `APP_ENV`, `FEATURE_FLAG`, masked `DB_PASSWORD` |
| `paperclip-day4-api` | `app.py` 웹서버 | 웹 요청 처리 | startup 한 줄(`RESPONSE_MODE=json`) + access log |

같은 `docker logs`인데 한쪽은 env가 다 찍히고 한쪽은 안 찍히는 이유가 이것이다. `report.sh`는 존재 이유 자체가 env 출력이고, `app.py`는 자기 동작에 필요한 것(mode, 요청 경로)만 남긴다. `app.py`도 env를 하나(`RESPONSE_MODE`)는 찍지만 `DB_PASSWORD` 같은 건 찍지 않는다.

그래서 "secret을 로그에 안 남기기"는 Docker 옵션이 아니라 **앱 코드가 책임지는 일**이다. `report.sh`처럼 masking을 직접 넣어야 한다.

### logs는 증거이자 유출 경로다

로그는 장애 분석 증거이면서 동시에 secret 유출 경로가 될 수 있다. `report.sh`가 password를 직접 출력하지 않고 masking한 것처럼, application log도 같은 기준이어야 한다.

#### log에 남겨도 되는 것과 안 되는 것

| 로그 예시 | 판단 |
|---|---|
| `APP_ENV=staging` | 남겨도 됨 — 환경 이름 정도는 가능 |
| `HTTP/1.1 200 OK` | 남겨도 됨 — 정상 확인 증거 |
| `GET /` | 남겨도 됨 — 접근 확인 증거 |
| `DB_PASSWORD=my-real-password` | 안 됨 — secret 노출 |
| `AWS_SECRET_ACCESS_KEY=...` | 안 됨 — credential 노출 |

기준은 **"동작을 설명하는 정보는 남기고, 들어가는 열쇠는 남기지 않는다"** 다. 환경 이름·status·요청 경로는 장애 분석에 필요하지만, password·token·access key는 그 자체가 시스템 진입 수단이다.

> **강사님 강조:** `AWS_SECRET_ACCESS_KEY=...` 같은 cloud credential은 로그·소스·env 출력 어디에도 **절대 평문으로 남기지 않는다.** access key 하나가 노출되면 계정 전체 권한으로 이어질 수 있어, password 노출보다 피해 범위가 크다. 의심되는 즉시 revoke/rotate한다.

값 확인이 필요하면 logs에 찍지 말고 masking된 script, `docker inspect`, health endpoint로 제한한다.

### 확인용 스크립트는 현업에서 안 쓴다

`report.sh` 같은 "env 찍어보는 확인용 스크립트"는 수업용 교보재다. production에서는 그대로 쓰지 않는다. secret이 제대로 들어갔는지 확인하려고 사람이 값을 출력하는 행위 자체를 없애는 방향이기 때문이다.

| `report.sh`가 하던 일 | 현업 방식 |
|---|---|
| env가 주입됐는지 확인 | health/readiness endpoint가 `config_loaded: true` 같은 **상태만** 노출 (값은 안 보여줌) |
| secret masking | 로깅 프레임워크가 자동 redaction (structured logger의 scrubbing 규칙, 관측 도구의 마스킹) |
| 값 직접 출력 | secret manager가 주입을 책임지고, 앱은 값을 "확인"하지 않고 그냥 쓴다 |
| 설정 누락 감지 | 필수 env가 없으면 startup에서 **fail-fast로 종료** (출력이 아니라 죽음) |

`report.sh`가 가르치는 건 스크립트 자체가 아니라 두 원칙이다. (1) 로그에 뭐가 남는지는 프로그램이 정한다, (2) secret은 값이 아니라 존재 여부만 노출한다. 도구가 스크립트 → 프레임워크/플랫폼으로 바뀔 뿐 기준은 같다. [[`.env`는 로컬 개발 패턴이다]]와 같은 맥락으로, 실습 도구는 production 구조가 아니라 습관을 훈련하는 것이다.

#### masking해도 위험하다

`***masked***`로 가렸다고 안전한 게 아니다. masking은 **그 출력 한 줄에서만** 값을 가릴 뿐, 다음 위험은 그대로 남는다.

| 위험 | 설명 |
|---|---|
| masking은 출력에만 적용된다 | 실제 값은 여전히 환경변수·메모리·`.env` 파일에 그대로 존재한다. 가린 건 표시뿐이다. |
| 마스킹 누락 한 번이면 끝 | 새 secret key가 추가됐는데 masking 규칙을 안 고치면 그 값이 평문으로 찍힌다. 사람이 매번 챙기면 언젠가 빠뜨린다. |
| 이미 노출된 값은 못 돌린다 | masking은 사전 예방일 뿐, 한 번 로그·screenshot·repository에 평문으로 남은 값은 revoke/rotate 외에 회수할 방법이 없다. |
| 가렸다는 안심이 더 위험하다 | "masking했으니 공유해도 됨" 같은 방심이 실제 값 노출로 이어진다. |

그래서 진짜 방어는 masking이 아니라 **secret이 애초에 출력될 수 있는 위치(로그·소스·image·repository)에 들어가지 않게 하는 것**이고, 노출이 의심되면 가리는 게 아니라 즉시 revoke/rotate다.

### 흔한 오해

- `docker ps` `Up` = 서비스 정상 → process가 떴을 뿐. `curl`로 HTTP까지 확인해야 한다.
- HTTP 200 = 정상 → body type, JSON schema, frontend rendering까지 봐야 한다.
- logs가 비어 있음 = 장애 → 요청을 먼저 보내고 다시 확인한다.
- backend log에 error 없음 = 정상 → frontend에서 parse error가 나면 사용자 기능은 실패다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
