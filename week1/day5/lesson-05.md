# 4교시: 환경변수와 설정 파일 지옥

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| README에 적어도 되는 값은 무엇인가? | `DB_HOST`, `DB_PORT`, `DB_NAME`, `API_URL`, `AI_MODEL`, `ENABLE_AI_SEARCH` — 노출돼도 피해가 없는 설정 키와 값. |
| GitHub에 올리면 안 되는 값은 무엇인가? | `OPENAI_API_KEY=sk-...` — 실제 key 값 자체. key 이름은 `.env.example`에 적어도 되지만 값은 절대 올리면 안 된다. |
| 친구 컴퓨터에서 바뀔 가능성이 큰 값은 무엇인가? | `DB_HOST`, `DB_PORT`, `API_URL` — 각자 로컬 환경에 따라 달라지는 값들. |
| `.env.example`에는 어떤 형태로 적어야 하는가? | 키 이름만 남기고 실제 값은 빈칸이나 placeholder로 적는다. 예: `OPENAI_API_KEY=여기에_실제_키_입력` |
| 코드는 같은데 왜 결과가 다를까? | 코드가 같아도 환경변수와 설정 파일이 다르면 앱의 동작은 달라진다. 내 컴퓨터의 설정과 친구 컴퓨터의 설정, 배포 환경의 설정이 각각 다를 수 있다. |

## notes

### 설정이 필요한 이유

코드를 바꾸지 않고 환경마다 다른 값을 쓰기 위해 설정을 코드 밖으로 뺀다.

```text
개발 환경: localhost DB 사용
테스트 환경: 테스트 DB 사용
운영 환경: 실제 DB 사용
```

| 설정 | 예시 |
|---|---|
| DB 접속 정보 | `DB_HOST`, `DB_PORT`, `DB_NAME` |
| 외부 API | `API_URL`, `OPENAI_API_KEY` |
| 실행 모드 | `NODE_ENV`, `APP_ENV` |
| 보안 값 | secret key, token |
| 기능 플래그 | `ENABLE_AI_SEARCH=true` |
| 파일 경로 | upload directory, log directory |

### 설정이 꼬이는 대표 상황

환경변수는 보이지 않는 설정이라 디버깅이 어렵다.

```text
.env 파일이 없다.
.env.example은 있는데 실제 값이 다르다.
README의 port와 .env의 port가 다르다.
변수 이름이 DB_HOST인지 DATABASE_HOST인지 헷갈린다.
secret을 GitHub에 올릴 뻔했다.
이전 프로젝트의 환경변수가 남아 있다.
터미널을 다시 열지 않아 변경값이 반영되지 않았다.
```

### 설정 drift

drift = 시간이 지나며 문서, 코드, 실제 환경이 서로 달라지는 현상.

| 위치 | 값 |
|---|---|
| README | `DB_PORT=3306` |
| `.env.example` | `DB_PORT=3307` |
| 내 컴퓨터 실제 환경변수 | `DB_PORT=3310` |
| backend 코드 기본값 | `DB_PORT=3306` |

이 상태에서는 "왜 내 컴퓨터만 안 되지?"가 반복된다. → Day3 lesson-04 RCA에서 다룬 expected와 actual이 달라지는 상황과 같다.

### .env 작성 기준

```text
# .env.example — GitHub에 올려도 되는 형태
DB_HOST=localhost
DB_PORT=5432
DB_NAME=appdb
API_URL=http://localhost:8080
AI_MODEL=gpt-example
OPENAI_API_KEY=여기에_실제_키_입력   ← 값은 절대 실제 키를 쓰지 않는다
ENABLE_AI_SEARCH=true
```

| 항목 | README | .env.example | GitHub |
|---|---|---|---|
| 설정 키 이름 | 가능 | 가능 | 가능 |
| 민감하지 않은 값 (`DB_PORT=5432`) | 가능 | 가능 | 가능 |
| 실제 API key 값 | 불가 | 불가 | **절대 불가** |

### AI 앱에서 설정이 더 많고 비싸지는 이유

- 어떤 모델을 쓸 것인가? (`AI_MODEL`)
- temperature, max token, timeout은 얼마인가?
- embedding model은 무엇인가?
- vector index 이름은 무엇인가?
- API key는 어디서 주입되는가?
- 무료 한도나 비용 제한은 어떻게 걸 것인가?

"작동하는 것"과 "안전하게 작동하는 것"은 다르다. API key가 코드나 화면에 노출되는 순간 이미 유출로 간주한다.

### 환경별 .env 파일 분리

설정을 하나의 `.env`에 다 몰아넣지 않고 환경마다 파일을 나눠서 관리한다.

| 파일 | 용도 |
|---|---|
| `.env` | 로컬 개발 — 내 컴퓨터에서만 사용 |
| `.env.development` | 개발 서버 환경 |
| `.env.staging` | 운영 전 검증 환경 |
| `.env.production` | 실제 운영 환경 |

- 파일이 나뉘어 있으면 "이 설정이 어느 환경 것인지"를 혼동하지 않는다.
- `.env`(로컬)와 `.env.production` 값이 섞이면 로컬에서 실제 운영 DB에 붙는 사고가 날 수 있다.
- `.env.production`은 GitHub에 절대 올리지 않는다. 로컬 `.env`도 마찬가지다.
- `.env.example` 하나만 GitHub에 올려두고, 각자 환경에 맞게 복사해서 값을 채운다.

```text
# GitHub에 올리는 것
.env.example          ← 키 이름만, 값은 placeholder

# GitHub에 올리지 않는 것 (.gitignore에 추가)
.env
.env.development
.env.staging
.env.production
```

### Week 2 Docker 연결

Docker는 실행할 때 환경변수를 주입할 수 있다. Compose 파일로 여러 프로그램의 설정을 한곳에서 관리한다.

```text
Docker는 설정을 없애는 도구가 아니라,
설정을 실행 단위와 함께 명시적으로 다루게 만드는 도구다.
```

핵심 문장:
```text
코드가 같아도 환경변수와 설정 파일이 다르면 앱의 동작은 달라질 수 있다.
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
