# 1교시: 애플리케이션 실행 환경은 코드만이 아니다

## 실습 확인 기록

| 프로그램 이름 | |
|---|---|
| 실행 명령 | |
| 필요한 runtime | |
| 필요한 외부 프로그램 | |
| 사용한 port | |
| 필요한 설정값 | |
| 데이터가 저장되는 위치 | |
| 실패했을 때 봐야 할 화면이나 로그 | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| "앱이 실행된다"고 말하려면 무엇을 봐야 하는가? | 명령 실행 성공, 브라우저 접속 성공, 로그에 에러 없음, DB 연결 성공, 데이터 읽기 성공, 다른 사람 컴퓨터에서도 재현 가능 — 이 모두가 확인돼야 한다. |
| "내 컴퓨터에서 한 번 켜짐"과 "운영 가능한 실행 환경"은 어떻게 다른가? | 한 번 켜짐은 단순히 명령이 실행된 것. 운영 가능한 실행 환경은 runtime, dependency, network, config, data가 모두 맞아서 다른 사람 컴퓨터에서도 재현되는 상태다. DevOps와 Cloud Native에서는 후자를 계속 묻는다. |
| AI 기능이 들어간 앱은 실행 조건이 왜 더 늘어나는가? | LLM API key, vector database, 모델 버전/tokenizer/GPU driver, cache, prompt와 retrieval 설정 등이 추가로 필요하기 때문이다. 즉 "코드만 받으면 실행된다"에서 더 멀어진다. |

## notes

### 앱 실행에 필요한 조건

| 조건 | 질문 | 예시 |
|---|---|---|
| 코드 | 무엇을 실행하는가? | frontend, backend, script |
| Runtime | 어떤 실행기가 필요한가? | Node.js, Python, Java |
| Dependency | 어떤 라이브러리가 필요한가? | npm package, pip package |
| Program | 외부 프로그램이 필요한가? | DB, cache, message broker |
| Network | 어디로 접속하는가? | localhost, port, API URL |
| Configuration | 설정은 어디서 오는가? | `.env`, config file |
| Data | 데이터는 어디에 저장되는가? | database folder, upload folder |
| Command | 어떤 명령으로 시작하는가? | `npm run dev`, `python app.py` |

### 조건이 빠졌을 때 증상

| 제거한 조건 | 예상 증상 |
|---|---|
| Node.js 버전이 다름 | 명령 자체가 실패하거나 문법 오류 발생 |
| 라이브러리 설치가 안 됨 | `module not found` |
| DB가 꺼져 있음 | `connection refused` |
| port가 겹침 | `already in use` |
| `.env` 값이 없음 | undefined config, login failure |
| 데이터 폴더가 없음 | file not found, empty result |

### Week 2 Docker 연결

| 오늘의 말 | Week 2 표현 |
|---|---|
| 실행에 필요한 프로그램 묶음 | image |
| 실제로 켜진 실행 단위 | container |
| 밖에서 접속할 입구 | port binding |
| 데이터가 남는 위치 | volume |
| 실행 시 주입하는 설정 | environment variable |

### 핵심 문장
- 앱 실행은 코드만의 문제가 아니라 runtime, dependency, network, config, data가 함께 맞아야 하는 문제다.
- Docker는 코드를 대신 짜 주는 도구가 아니라, 실행 조건을 포장하고 격리하고 재현하려는 도구다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
