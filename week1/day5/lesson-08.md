# 7-8교시: Docker가 등장하는 자리와 로컬 환경 문제 공유

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 내가 불편했던 로컬 환경 문제는 어느 범주에 속하는가? | |
| Docker가 줄여 줄 것 같은 부분은 무엇인가? | |
| Docker가 대신 해결하지 못할 것 같은 부분은 무엇인가? | |
| Week2에서 가장 확인하고 싶은 것은 무엇인가? | |

## notes

### Day5 문제 → Docker 단어

오늘 1~6교시에서 다룬 문제들이 Week2 Docker 목차가 된다.

| Day5 문제 | Docker 단어 |
|---|---|
| 프로그램 설치가 번거롭다 | image |
| 실행 중인 프로그램을 구분하고 싶다 | container |
| port가 겹친다 | port binding |
| 데이터는 남겨야 한다 | volume |
| 설정값이 필요하다 | environment variable |
| 여러 프로그램을 함께 켜야 한다 | compose |
| 정리하고 싶다 | stop, remove, prune |

### Docker 4가지 동사

| 동사 | 의미 |
|---|---|
| 포장한다 | 필요한 실행 조건을 image로 묶는다 |
| 격리한다 | 내 OS 전체에 섞지 않고 container로 실행한다 |
| 연결한다 | port, volume, env를 명시적으로 연결한다 |
| 재현한다 | 같은 image와 설정으로 다시 실행한다 |

### 로컬 직접 설치 vs Docker 방식

| 관점 | 로컬 직접 설치 | Docker 방식 |
|---|---|---|
| 설치 | OS에 프로그램을 등록 | image를 받아 실행 |
| 실행 단위 | service/process | container |
| 버전 변경 | 재설치 또는 별도 설치 | image tag 변경 |
| port | OS port 직접 사용 | host와 container port 연결 |
| data | 임의의 로컬 폴더 | volume으로 명시 |
| 삭제 | 흔적 확인 필요 | container/image/volume 구분 |
| 재현 | 문서 의존 | Dockerfile/Compose로 절차화 |

### Docker가 해결하지 않는 것

과대평가하지 않는다.

```text
Docker가 코드를 고쳐 주지는 않는다.
Docker가 DB 설계를 대신하지 않는다.
Docker가 secret 관리를 자동으로 안전하게 해 주지는 않는다.
Docker를 잘못 쓰면 image와 volume이 쌓여 디스크를 많이 쓸 수 있다.
Docker도 network, storage, permission 문제를 만든다.
```

### 학생 질문 → Week2 연결

| 질문 | Week2에서 다룰 위치 |
|---|---|
| 설치하지 않고 DB를 써 볼 수 있나요? | image, container |
| port가 겹치면 어떻게 하나요? | port binding |
| 데이터는 container를 지우면 사라지나요? | volume |
| 설정값은 어디에 넣나요? | env, `.env`, compose |
| 여러 프로그램을 한 번에 켤 수 있나요? | Docker Compose |
| 다 쓰고 깔끔하게 지우려면요? | cleanup |

### AI 엔지니어링에서 Docker가 등장하는 자리

AI 기능은 dependency와 설정이 많아서 Docker의 장점이 더 빨리 체감된다.

- vector DB를 빠르게 띄워 RAG 실험을 한다
- model serving 서버를 격리된 환경에서 실행한다
- GPU driver와 library version 문제를 줄인다
- prompt evaluation 도구, monitoring 도구를 함께 실행한다
- 실험 환경을 다른 사람에게 그대로 전달한다

### Week2 예고

Week2에서는 오늘의 문제를 실제 명령으로 바꾼다.

```text
image 받기
container 실행하기
port 연결하기
volume 붙이기
environment variable 주입하기
여러 service를 compose로 함께 실행하기
사용한 자원 정리하기
```

핵심 문장:
```text
Docker는 로컬 실행 환경의 설치, 격리, 연결, 재현, 정리 문제를 다루기 위해 등장한다.
내가 겪은 로컬 환경 문제를 설치, 버전, port, 설정, 데이터, 삭제, 재현 중 하나로 분류할 수 있다.
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
