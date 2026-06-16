# 5교시: 삭제해도 남는 것들

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 다시 만들 수 있는 것은 무엇인가? | `node_modules`, `.venv`, `dist`, `build`, `.cache` — 명령 하나로 재생성 가능한 것들. 지워도 된다. |
| 지우기 전에 백업해야 할 것은 무엇인가? | `db-data`, `uploads`, `generated-images` — 삭제하면 복구가 어렵거나 불가능한 것들. |
| secret이 들어 있을 수 있는 것은 무엇인가? | `.env` — API key, DB 비밀번호 등 실제 값이 들어 있다. 삭제 전 내용을 확인하고, 필요하면 백업한다. |
| README에 정리 방법을 적는다면 어떤 순서가 좋을까? | 1) 재생성 가능한 것 먼저 삭제 → 2) 데이터/업로드 백업 → 3) service 등록 해제 → 4) config/log 정리 순서. "무엇인지 알고 지운다"가 핵심이다. |

## notes

### 프로그램이 남기는 흔적

프로그램 삭제 = 실행 파일 삭제만이 아니다.

| 흔적 | 설명 | 지워도 되는가 |
|---|---|---|
| 실행 파일 | 실제 프로그램 binary | 재설치하면 됨 |
| package cache | 설치 속도를 위해 남겨 둔 파일 | 대부분 가능 |
| service 등록 | 백그라운드 자동 실행 항목 | 해제해야 함 |
| data folder | DB 데이터, 업로드 파일 | **백업 후 삭제** |
| config file | 설정값, 계정 정보, 경로 | 내용 확인 후 |
| log file | 실행 기록과 에러 기록 | 보통 가능 |
| plugin/extension | IDE나 tool에 붙은 추가 기능 | 재설치하면 됨 |

삭제가 어려운 이유: "지워도 되는 것"과 "지우면 복구가 어려운 것"이 섞여 있기 때문이다.

### 삭제의 두 종류

```text
프로그램 삭제: 실행 파일과 등록 정보 제거
데이터 삭제: 내가 만든 데이터와 상태 제거
```

DB를 예로 들면 프로그램을 지워도 data folder는 남을 수 있다. 반대로 data folder를 지우면 프로그램은 남아 있어도 이전 데이터는 사라진다.

### 목록별 분류

| 항목 | 분류 | 이유 |
|---|---|---|
| `node_modules` | 재생성 가능 | `npm install`로 다시 만들 수 있음 |
| `.venv` | 재생성 가능 | `python -m venv`로 다시 만들 수 있음 |
| `dist`, `build` | 재생성 가능 | 빌드 명령으로 다시 만들 수 있음 |
| `.cache` | 재생성 가능 | 자동으로 다시 생성됨 |
| `logs` | 확인 후 삭제 | 디버깅 중이면 보존 |
| `uploads` | 백업 필요 | 사용자가 올린 파일, 복구 불가 |
| `db-data` | 백업 필요 | DB 데이터, 삭제하면 사라짐 |
| `generated-images` | 상황에 따라 | 재생성 가능하면 삭제 가능 |
| `.env` | 내용 확인 필요 | secret이 들어 있을 수 있음 |

> "지우지 마라"가 아니라 "무엇인지 알고 지우라"

### 로컬 디스크 문제를 운영 관점으로 보기

내 컴퓨터 정리 문제는 운영 관리의 작은 버전이다.

| 로컬 문제 | 운영 환경의 대응 개념 |
|---|---|
| 로그가 계속 쌓임 | log rotation |
| 캐시가 커짐 | cache eviction |
| 빌드 산출물이 쌓임 | artifact retention |
| DB 데이터가 커짐 | backup, archive, retention |
| 쓰지 않는 프로그램이 남음 | lifecycle management |

### AI 개발은 디스크를 특히 많이 쓴다

실험을 많이 할수록 "어떤 결과물이 남았는가"를 관리하지 않으면 금방 공간이 부족해진다.

- 모델 파일
- embedding cache
- vector index
- dataset
- experiment output
- log와 trace
- 이미지/음성 생성 결과

### Week 2 Docker 연결

Docker도 정리가 필요하다. 다만 정리 대상이 더 명확해진다.

| 로컬 설치 방식 | Docker 방식 |
|---|---|
| 어디에 깔렸는지 찾기 어려움 | image/container/volume으로 구분 |
| 서비스가 OS에 남을 수 있음 | container stop/remove |
| 데이터 폴더 위치가 흩어짐 | volume 이름으로 관리 |
| 캐시와 산출물이 섞임 | build cache, image layer로 관리 |

```text
Docker는 정리를 자동으로 대신해 주는 마법이 아니라,
무엇을 정리해야 하는지 경계를 더 분명하게 만드는 도구다.
```

핵심 문장:
```text
프로그램 삭제는 실행 파일 삭제만이 아니라
service, config, data, cache, log를 구분해서 보는 문제다.
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
