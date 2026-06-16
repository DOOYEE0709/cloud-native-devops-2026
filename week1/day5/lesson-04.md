# 3교시: 포트 번호와 localhost 충돌

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| `address already in use` 에러가 나면 문제는 코드인가, 컴퓨터 환경인가? | 둘 중 하나로 단정하지 않는다. "이미 같은 입구를 누군가 쓰고 있다"는 환경 문제다. 코드를 고쳐도 해결되지 않고, 어떤 프로세스가 해당 port를 점유 중인지 먼저 확인해야 한다. |
| 동시에 실행할 수 없는 것은 무엇인가? (백엔드 A, B 모두 8080 / DB A, B 모두 3306) | 백엔드 A와 B, DB A와 B — 각각 같은 port를 쓰므로 동시에 실행할 수 없다. port는 한 번에 하나의 프로세스만 listen할 수 있다. |
| port를 바꾸면 어느 설정을 같이 바꿔야 하는가? | `.env`의 port 값, DB client 접속 정보, README 실행 설명, integration test config, 문서 스크린샷까지 연결된 설정 전체를 함께 바꿔야 한다. |
| 다른 사람이 이 환경을 재현하려면 어떤 표가 필요할까? | 서비스별로 어떤 port를 쓰는지 정리한 표. 어느 port가 겹치는지, 각 서비스의 실행 순서는 어떻게 되는지를 명시해야 한다. |

## notes

### localhost와 port

```text
localhost = 내 컴퓨터를 가리키는 이름
port      = 그 컴퓨터 안에서 프로그램을 찾아가는 번호 (방 번호)
```

같은 컴퓨터에서 같은 port를 두 프로그램이 동시에 쓸 수 없다.

| 주소 | 역할 |
|---|---|
| `localhost:3000` | 프론트엔드 개발 서버 |
| `localhost:8080` | 백엔드 API 서버 |
| `localhost:5432` | PostgreSQL |
| `localhost:6379` | cache 서버 |

### port 번호만 바꾸면 생기는 연쇄 수정

port 변경은 한 줄 수정이 아니라 연결된 설정 전체의 수정이다.

| 바뀌는 것 | 예시 |
|---|---|
| backend `.env` | `DB_PORT=3307` |
| DB client 접속 정보 | Host, port |
| README 실행 설명 | 접속 명령 수정 |
| 테스트 설정 | integration test config |
| 스크린샷/문서 | 예전 port 정보 정리 |

### 충돌 원인 후보

```text
1. 이전에 켠 서버가 아직 살아 있다.
2. OS 서비스로 등록된 프로그램이 자동 실행 중이다.
3. 다른 프로젝트가 같은 port를 사용 중이다.
4. IDE나 개발 도구가 내부 서버를 켜 두었다.
5. Docker, VM, WSL 같은 다른 실행 환경이 port를 잡고 있다.
```

명령어 암기보다 관점이 중요하다 — **"누가 이 port를 쓰고 있는가"** 를 먼저 확인한다.

### AI 앱에서 port가 늘어나는 이유

AI 앱은 구성 요소가 많아서 port 설계가 필요해진다.

| 구성 요소 | 포트 예시 |
|---|---|
| web UI | 3000 |
| API server | 8080 |
| vector DB | 6333 |
| model serving endpoint | 8000 |
| monitoring dashboard | 3100 |
| prompt playground | 7860 |

실험을 여러 개 동시에 띄우면 port 충돌이 흔하다. 특히 모델 서빙, vector DB, observability 도구를 같이 띄울 때 port 설계가 필요해진다.

### 포트 표를 미리 정해두면 충돌을 막을 수 있다

port 충돌은 "나중에 고치는 것"보다 **팀 전체가 사전에 합의한 표를 만들어두는 것**이 훨씬 싸다. 아래처럼 프로젝트 시작 전 port를 배정해두면 겹칠 일이 없다.

| 서비스 | port |
|---|---|
| MySQL | 3306 |
| PostgreSQL | 5432 |
| Redis | 6379 |
| MongoDB | 27017 |
| Backend | 5000 |
| Backend 2 | 5001 |
| Frontend | 5173 |
| Admin Frontend | 5174 |

- 이 표가 있으면 팀원 누가 실행해도 port가 겹칠 일이 없다.
- `.env`에 port 값을 하드코딩하지 않고 이 표를 기준으로 맞춘다.
- 새 서비스가 추가될 때 표를 먼저 업데이트하고 코드를 작성한다.
- 단, 서비스 수가 많아질수록 이 표를 손으로 관리하는 것도 부담이 된다 → Docker의 port binding으로 이어진다.

### Week 2 Docker 연결

Docker는 container 안쪽 port와 내 컴퓨터에서 접속하는 port를 나누어 생각한다.

```text
host port  →  container port
  3307     →     3306
```

```text
Docker의 port binding은 내 컴퓨터의 입구 번호와
container 내부의 입구 번호를 연결하는 약속이다.
```

핵심 문장:
```text
port 충돌은 실행 중인 프로그램들이 같은 네트워크 입구를 쓰려고 할 때 생기며,
port 변경은 관련 설정 전체에 영향을 준다.
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
