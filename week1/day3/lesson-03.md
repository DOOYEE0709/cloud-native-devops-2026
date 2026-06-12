# 3교시: 서비스 실행 조건 - source, 실행 환경, command, 포트, data, 외부 의존성

## 실습 확인 기록

| 명령 | 결과 |
|---|---|
| | |

## notes

### 서비스 실행 조건 6가지
- 실습을 바탕으로 씀.

| Condition | 질문 | 이 서버의 값 |
|---|---|---|
| Source | 코드는 어디에 있는가? | `week1/day3/index.html` |
| 실행 환경 | 무엇으로 실행하는가? | Python 3 |
| Command | 어떻게 시작하는가? | `python3 -m http.server 8000` |
| 포트 | 어디로 접속하는가? | `http://localhost:8000` |
| Data | 어떤 파일이 필요한가? | 현재 디렉터리의 정적 파일 |
| 외부 의존성 | 외부 서비스가 필요한가? | 없음 |

### 누락 조건별 실패 증상
- 이외에도 많은 실패 증상이 있음.

| 누락 조건 | 흔한 증상 | 확인 명령 |
|---|---|---|
| Source 없음 | 404 또는 디렉터리 목록 | `ls`, URL 경로 |
| 실행 환경 없음 | `command not found` | `python3 --version` |
| Command 틀림 | 서버 미실행 | terminal output |
| 포트 충돌 | `address already in use` | server error |
| Data 누락 | 기대한 내용이 안 보임 | `cat index.html` |
| 외부 의존성 누락 | external call 실패 | 의존성 note |

### 외부 의존성 최소화 - 강사님 예시
- 어느 게임 회사에서 개발자가 게임 엔진 자체를 직접 만든 사례
- 장점: 외부 엔진에 의존하지 않아서 엔진 변경/종료에 영향받지 않음. 내부 구조를 완전히 통제 가능.
- 단점: 그 엔진으로 개발할 수 있는 사람만 입사 가능 → 채용 풀이 좁아짐
- 핵심: 외부 의존성을 줄이는 것은 안정성을 높이지만, 그만큼 내부 역량에 대한 요구도 높아진다.

### 확인 질문 답변

| 질문 | 답변 |
|---|---|
| local static server의 실행 환경은 무엇인가? | Python 3 — `python3 --version`으로 확인하며, Python 3가 없으면 `command not found`로 서버를 시작할 수 없다. |
| 포트가 빠진 README는 어떤 문제를 만들 수 있는가? | 다른 사람이 서버를 실행해도 어느 주소로 접속해야 하는지 알 수 없다. `localhost:8000`인지 `localhost:3000`인지 모르면 접속 자체를 못 한다. |
| 외부 의존성이 없다는 것도 왜 기록해야 하는가? | 두 가지 의미가 있다. (1) 기준점: 나중에 API나 DB가 추가됐을 때 "원래는 없었다"는 비교 기준이 생긴다. 빈칸과 "없음"은 다르다. (2) 안정성: 외부 의존성이 없다는 것은 외부 서비스가 죽어도 내 서비스가 영향받지 않는다는 뜻이다. 의존성이 늘수록 장애 가능성도 늘어나므로 의존성을 최소화하고 언어/런타임 자체를 잘 쓰는 것이 기본이다. |

### Week 1 → Week 2 Docker 연결

| Week 1 (로컬 환경) | Docker 구성 요소 | Docker로 넘어가면 |
|---|---|---|
| 실행 환경 (Python 3) | Image | 구동에 필요한 환경을 Image로 고정해서 재현성 확보 |
| 서버 프로세스 실행 | Container | Image로 실행되는 격리된 실행 환경 |
| 포트 (localhost:8000) | Port Binding | 호스트 포트를 컨테이너 포트에 연결 |
| 파일 위치 (index.html) | Volume | 컨테이너 외부에 파일을 두어 데이터 유지 |
| 설정값 관리 (PORT=8000) | Environment Variable | 환경 설정을 코드와 분리해서 주입 |
| 로그 확인 (서버 터미널) | Logs | 컨테이너 안 stdout/stderr 관찰 |

### 다음 주차 연결
- Docker: source/실행 환경/command → image + container command + port publish
- Kubernetes: 포트와 실행 환경 상태 → manifest로 선언
- AWS/Terraform: 외부 의존성과 실행 환경 → 관리형 리소스로 확장

## 막힘 기록

| 증상 | 확인한 것 |
|---|---|
| | |
