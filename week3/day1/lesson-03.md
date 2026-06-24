# 3교시: 인프라 엔지니어가 MSA에서 알아야 할 것

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker compose config > /tmp/w3d1-compose-config.txt` | compose 최종 설정을 파일로 저장해 service contract 값을 찾음 |
| frontend published port | `18083` |
| api container port | `8080` (expose), host debug `18084` |
| api DB host | `DB_HOST=db` |
| worker API URL | `http://api:8080/api/status` |
| db volume name | `msa-db-data` |
| db healthcheck command | `pg_isready -U paperclip -d paperclip` |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| MSA 운영자는 비즈니스 로직을 다 알아야 하는가? | 아니다. 단, 각 service의 image/build, port, env, dependency, health/log 위치는 반드시 알아야 한다. 운영은 코드 내부가 아니라 운영 증거로 정상/비정상을 판단한다. |
| `condition: service_healthy`의 의도는? | DB의 healthcheck가 통과한 뒤에 api를 시작하려는 것. container running이 아니라 readiness 기준으로 의존 순서를 맞춘다. |
| `ports: 18084:8080`은 왜 있나? | 강의 debug용. host에서 api를 직접 curl로 확인하기 위함이며, 실제 사용자 경로(frontend)와는 구분된다. |
| 운영자가 host port와 container port를 헷갈리면? | curl 대상이 틀려서 정상 service를 장애로 오판한다. |

## notes

### 핵심 질문 — service마다 이것만은 안다

```text
이 service는 어떤 image로 실행되는가?
어떤 port를 열고 누구에게 공개하는가?
어떤 environment variable이 없으면 실패하는가?
어떤 service에 의존하는가?
정상 상태는 어떤 endpoint나 log로 확인하는가?
data를 어디에 저장하는가?
```

### Service Contract 표 (Day1 실습 앱)

| Service | 실행 기준 | Port | Env | Dependency | Health/Log |
|---|---|---|---|---|---|
| `frontend` | `nginx:1.27-alpine` | host `18083` → container `80` | 없음 | `api` | nginx access/error log |
| `api` | `build: ./api` | expose `8080`, host `18084` | `DB_HOST`, `DB_PORT` | `db` | `/health`, api JSON log |
| `worker` | `build: ./worker` | host 공개 없음 | `API_URL`, `WORKER_INTERVAL_SECONDS` | `api` | worker JSON log |
| `db` | `postgres:16-alpine` | host 공개 없음, internal `5432` | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | volume | `pg_isready`, db log |

이 표는 문서 장식이 아니라 **장애 시 확인 순서**가 된다.

### compose.yaml에서 contract 읽는 법

```yaml
api:
  build: ./api
  environment:
    DB_HOST: ${DB_HOST:-db}
    DB_PORT: ${DB_PORT:-5432}
  expose:
    - "8080"
  ports:
    - "18084:8080"
  depends_on:
    db:
      condition: service_healthy
  healthcheck:
    test: ["CMD", "python", "-c", "... /health ..."]
```

| 줄 | 의미 |
|---|---|
| `build: ./api` | API image는 local Dockerfile로 만든다 |
| `DB_HOST: db` | API container는 DB를 service name `db`로 찾는다 |
| `expose: 8080` | Compose network 내부에서 8080을 사용한다 |
| `ports: 18084:8080` | 강의 debug용으로 host에서도 API를 직접 확인 |
| `condition: service_healthy` | DB healthcheck 통과 후 API를 시작하려는 의도 |
| `healthcheck` | container running이 아니라 API readiness를 확인 |

### 운영자가 모르면 생기는 문제

| 모르는 것 | 생기는 문제 |
|---|---|
| host port와 container port | curl 대상이 틀려서 정상 service를 장애로 오판 |
| service name DNS | container 내부에서 `localhost`로 DB를 찾으려다 실패 |
| env default | `.env` 값이 바뀌었는데 compose config를 안 보고 넘어감 |
| healthcheck 의미 | running인데 준비 안 된 service를 정상으로 오판 |
| volume lifecycle | `down -v`로 DB data를 날림 |

### 개발팀 전달사항 (운영에 필수)

운영자가 service를 안정적으로 운영하려면 개발팀에서 다음을 함께 넘겨받아야 한다.

| 항목 | 내용 |
|---|---|
| 배포 문서 | 빌드/배포 절차, 마이그레이션(필요시), 롤백 절차 |
| 설정 정보 | 필수 환경변수 목록, 기본값, 예시 |
| 장애 대응 가이드 | 자주 발생하는 장애와 복구 방법 |
| 모니터링 지표 | 핵심 비즈니스 지표, 애플리케이션 지표 |

### healthcheck — 없으면 404, 그리고 200~499를 정상으로 잡는 이유

**healthcheck가 없으면 배포 후 404 사고.** LB/k8s는 트래픽을 보내기 전에 특정 경로(`/health` 등)로 GET해서 인스턴스 생사를 확인한다. 앱에 그 endpoint가 없으면 → 404 → 플랫폼이 "죽음"으로 오판 → 트래픽 차단 → "배포했더니 되던 게 안 돼요". 코드는 멀쩡한데 health 경로가 빠져서 생기는 전형적 사고.

```text
LB → GET /health → 200?  → 정상, 트래픽 보냄
                 → 404?   → 비정상, rotation에서 제외
```

**왜 200~499를 정상으로?** HTTP 코드 의미를 보면 4xx도 서버는 살아있다.

| 코드 | 의미 | 서버 상태 |
|---|---|---|
| 2xx/3xx | 성공/리다이렉트 | 살아있음 |
| 4xx | 클라이언트 잘못(404/401/403) | **살아있음** — 서버가 "잘못된 요청"이라고 정상 응답한 것 |
| 5xx | 서버 잘못(500/502/503) | **고장** |

4xx는 앱이 요청을 받아 라우팅하고 응답까지 했다는 증거다. 진짜 고장 신호는 **5xx, 연결거부, 타임아웃, 무응답**. 그래서 `200~499 = 정상`은 "5xx만 아니면 일단 살아있다"는 **느슨한 liveness 체크**다. 404 오판으로 인스턴스를 죽이는 사고를 막으려는 의도.

| 기준 | 장점 | 단점 |
|---|---|---|
| 엄격(200만) | 진짜 준비된 인스턴스만 트래픽 (readiness) | health 경로 빠지면 404로 전부 죽음 판정 |
| 느슨(200~499) | 404/401에도 안 죽음, 오판 방지 | 앱이 망가져 404만 뱉어도 정상으로 보일 위험 |

보통 liveness(살아있나?)는 느슨하게, readiness(트래픽 받을 준비됐나?)는 전용 `/health`에서 200 + 의존성까지 엄격하게 본다. 실습 앱 `api`는 `/health` 200 확인, `db`는 `pg_isready`로 readiness까지 확인한다.

### 환경변수와 secret — 값은 외부에서 주입된다

compose.yaml/Dockerfile은 git에 올라가는 코드라, 민감한 값(DB 비밀번호, API 키, 토큰)은 직접 적지 않고 외부에서 따로 관리한다. 그래서 `docker compose config`만 봐서는 env 값이 다 안 보일 수 있다.

실습 앱에도 흔적이 있다:

```yaml
db:
  environment:
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-paperclip-local-only}
```

| 표기 | 의미 |
|---|---|
| `${POSTGRES_PASSWORD}` | 실제 값은 파일에 없고 외부(환경변수/`.env`)에서 주입 |
| `:-paperclip-local-only` | 주입 안 될 때 쓸 기본값 (이름처럼 로컬 전용, 실서비스용 아님) |

labs에 `.env.example`만 있고 `.env`는 없는 것도 같은 이유 — 키 이름(예시)만 공유하고 실제 값은 각자 따로 채운다.

| 단계 | secret 관리 위치 |
|---|---|
| 로컬 개발 | `.env` 파일 (git 제외, `.gitignore`) |
| compose/k8s | 환경변수 주입, Docker secret, k8s Secret |
| 클라우드/실무 | AWS Secrets Manager, GCP Secret Manager, HashiCorp Vault |

운영자 관점: compose에 변수 **이름은 보여도 실제 값은 안 보일 수 있다**. "env가 비어 보인다 ≠ 설정 안 됨" — 외부에서 주입되는 구조일 수 있으니 `.env`·secret manager·배포 파이프라인을 확인한다.

### 핵심

MSA에서 인프라 엔지니어가 먼저 작성해야 하는 문서는 멋진 아키텍처 소개가 아니라 **service contract 표**다. 이 표가 있어야 장애 상황에서 어디를 먼저 볼지 결정할 수 있다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
