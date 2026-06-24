# 1교시: Week2 10분 요약 + MSA를 운영 토폴로지로 보기

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `cd week3/day1/labs/msa-demo` | 표준 실습 앱 디렉터리로 이동 |
| `docker compose config` | 실행 전 frontend/api/worker/db의 port, env, healthcheck, volume을 파일로 먼저 확인 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 단일 container 정상과 MSA 정상의 차이는? | 단일 container는 `docker ps`에 `Up`이면 대부분 해결된 것이지만, MSA는 모든 service가 `Up`이어도 서로 기대한 주소·port·설정·readiness로 연결돼야 정상이다. |
| 표준 실습 앱의 외부 진입점과 내부 service name은? | 외부 진입점은 frontend(`localhost:18083`), api(`localhost:18084` debug). 내부 주소는 `frontend:80`, `api:8080`, `db:5432`, `worker`. |
| worker는 사용자 요청을 직접 받는가? | 받지 않는다. 하지만 API나 DB 장애가 나면 worker도 실패 로그를 남기므로 사용자 경로와 background 경로를 구분해야 한다. |
| MSA 수업의 목표는 명령 암기인가? | 아니다. 같은 명령을 여러 service에 적용하면서 어느 service가 전체 장애의 단서인지 찾아내는 것이 목표다. |

## notes

### Week3의 질문 전환

```text
container 하나가 켜졌는가?
  ↓
여러 service가 서로 기대한 주소, port, 설정, readiness 상태로 연결되어 있는가?
```

### Week2 개념을 MSA로 연결하기

| Week2 개념 | 단일 container에서의 의미 | MSA에서 다시 보는 의미 |
|---|---|---|
| image | 실행 파일 묶음 | service별 배포 단위 |
| container | 실행 중인 process | service instance |
| port publish | host에서 접근할 통로 | 외부 진입점과 debug port 구분 |
| environment | runtime config | service 간 주소, credential, feature flag |
| logs | process 출력 | 여러 service의 request 흐름 증거 |
| volume | data 보존 | stateful service의 lifecycle |
| network | container 통신 | service boundary와 dependency map |

### 표준 실습 앱 토폴로지 (Day1~Day2 공통)

| Service | 역할 | 외부 접근 | 내부 주소 | 주요 증거 |
|---|---|---|---|---|
| `frontend` | 사용자 진입점, nginx reverse proxy | `localhost:18083` | `frontend:80` | browser, nginx log |
| `api` | 상태 API, DB 연결 확인 | `localhost:18084` | `api:8080` | `/health`, `/api/status`, api log |
| `worker` | background에서 API 상태 확인 | 없음 | `worker` | worker log |
| `db` | PostgreSQL | 없음 | `db:5432` | healthcheck, db log, volume |

요청 흐름:

```text
browser -> frontend:80 -> api:8080 -> db:5432
worker  -> api:8080  -> db:5432
```

### docker compose config에서 볼 것

| 확인 지점 | 왜 보는가 |
|---|---|
| `frontend.ports` | 사용자가 어디로 들어오는지 확인 |
| `api.ports`와 `api.expose` | host debug port와 internal port 구분 |
| `api.environment.DB_HOST` | API가 DB를 어떤 service name으로 찾는지 확인 |
| `worker.environment.API_URL` | worker가 API를 어떤 주소로 호출하는지 확인 |
| `db.healthcheck` | DB 준비 상태를 무엇으로 판단하는지 확인 |
| `volumes.msa-db-data` | DB data가 container 삭제 후에도 남을 수 있는지 확인 |

### 모두 Up이어도 정상이 아니다

| 상황 | container 상태 | 사용자 경험 | 먼저 볼 증거 |
|---|---|---|---|
| frontend만 정상 | frontend Up | 화면은 뜨지만 데이터 없음 | nginx log, api URL |
| api는 Up, DB 연결 실패 | api Up | API 503 또는 JSON error | `/health`, api log |
| db는 늦게 준비됨 | db starting | API readiness 실패 | db healthcheck |
| worker 실패 | worker Up 또는 restart | 사용자 화면은 정상일 수 있음 | worker log |

### build vs image — 이미지를 가져오나, 만드나

Week2와 달리 labs에 `docker compose` 외에 service별 Dockerfile(`api/Dockerfile`, `worker/Dockerfile`)이 있는 이유. compose에서 두 패턴이 섞여 있다.

```yaml
frontend:
  image: nginx:1.27-alpine   # 이미 만들어진 공식 이미지를 가져옴
db:
  image: postgres:16-alpine  # 마찬가지
api:
  build: ./api               # Dockerfile로 우리 이미지를 직접 만듦
worker:
  build: ./worker            # 마찬가지
```

| 서비스 | 방식 | 이유 |
|---|---|---|
| frontend | `image: nginx` | 공식 이미지 그대로, 설정/페이지만 bind mount로 주입 |
| db | `image: postgres` | 표준 DB 이미지를 그대로 사용 |
| api | `build: ./api` | 우리 코드(`app.py`)를 담은 우리만의 이미지가 필요 |
| worker | `build: ./worker` | `worker.py`를 담은 이미지가 필요 |

핵심: `image`는 가져오기, `build`는 만들기. Week2가 남이 만든 이미지를 실행하는 데 집중했다면, Week3는 우리 코드가 들어간 이미지를 직접 빌드한다.

### Dockerfile 파일 이름 인식

`build: ./api`는 "`./api` 디렉터리(빌드 컨텍스트)에서 빌드하라"는 뜻이고, Docker는 그 안에서 `Dockerfile`이라는 이름을 **기본으로 자동 인식**한다. 이름이 다르면(`Dockerfile.dev` 등) 경로를 명시해야 한다.

```yaml
api:
  build:
    context: ./api              # 빌드 기준 폴더 (COPY 경로 기준)
    dockerfile: api.Dockerfile  # 사용할 Dockerfile 이름 지정
```

| 표기 | 의미 |
|---|---|
| `build: ./api` | `./api`에서 `Dockerfile` 자동 인식 |
| `build.context` | 빌드의 기준이 되는 폴더 |
| `build.dockerfile` | 그 안에서 쓸 Dockerfile 파일 이름/경로 직접 지정 |

한 폴더에서 용도별 이미지를 여러 개(`Dockerfile.dev`, `Dockerfile.prod`) 만들 때 자동 인식이 안 되므로 `dockerfile:`로 골라준다.

### 핵심

MSA는 코드 구조가 아니라 운영 토폴로지, 의존성, 장애 전파의 문제로 읽는다. 단일 container 정상 ≠ 전체 서비스 정상.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
