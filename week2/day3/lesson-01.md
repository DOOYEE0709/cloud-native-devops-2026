# 1교시: Image artifact 기준 잡기 - image, layer, tag, digest, registry

## 실습 확인 기록

| 명령 | 설명 | 결과 |
|---|---|---|
| `docker pull nginx:1.27-alpine` | registry에서 nginx 1.27-alpine image를 local로 가져온다 | ![pull nginx](assets\lesson-01\pull-nginx.png) |
| `docker images nginx` | local에 저장된 nginx image 목록을 확인한다 | ![images nginx](assets\lesson-01\images-nginx.png) |
| `docker history nginx:1.27-alpine` | image가 어떤 layer 흐름으로 만들어졌는지 확인한다 | ![history nginx](assets\lesson-01\history-nginx.png) |
| `docker image inspect nginx:1.27-alpine --format "{{.Id}} {{.Architecture}} {{.Size}}"` | image ID, architecture, size를 확인한다 | ![inspect meta](assets\lesson-01\inspect-meta.png) |
| `docker image inspect nginx:1.27-alpine --format "{{json .RepoTags}} {{json .RepoDigests}}"` | image의 tag와 digest를 확인한다 | ![inspect digest](assets\lesson-01\inspect-digest.png) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| image와 container의 차이는? | image는 container를 만들기 위한 읽기 전용 실행 재료다. container는 image로 만들어진 실행 중인 process다. 같은 image로 container를 여러 개 만들 수 있다. |
| layer란 무엇인가? | image 내부를 구성하는 단위다. Dockerfile의 instruction 하나가 layer 흔적 하나를 남긴다. `docker history`로 layer 흐름을 볼 수 있다. |
| tag와 digest의 차이는? | tag는 사람이 붙인 이름표로 content가 바뀌어도 같은 tag를 유지할 수 있다. digest는 registry 기준 content 식별자로 재현성 판단에 쓴다. |
| local build image에서 digest가 비어 있으면? | 오류가 아니다. registry에 push/pull된 적 없는 image는 `RepoDigests`가 비어 있을 수 있다. |
| registry가 필요한 이유는? | local image는 내 컴퓨터에만 있다. 다른 컴퓨터, CI runner, Kubernetes cluster가 같은 image를 쓰려면 registry에 push되어 있어야 한다. |
| build 성공이 납품 기준이 되지 않는 이유는? | `docker run`으로 container를 띄우고 `curl`로 HTTP 응답까지 확인해야 사용자가 접근 가능한 정상 상태다. `docker ps`의 `Up`은 process가 떠 있다는 것이지 서비스가 정상이라는 뜻이 아니다. |

## notes

### 오늘의 artifact 기준 (`paperclip-static-site:day3`)

```text
image tag    : paperclip-static-site:day3
build        : docker build 성공 + docker images 출력
run          : container Up 상태
verify       : HTTP/1.1 200 OK + HTML 본문 확인
handoff      : README에 build/run/check/cleanup 기록
```

### 각 명령이 답하는 질문

```text
docker pull      : registry에서 image를 가져온다
docker images    : local에 어떤 image reference가 있는지 본다
docker history   : image가 어떤 layer 흐름으로 만들어졌는지 본다
docker inspect   : image metadata, tag, digest, architecture, size를 본다
```

### 개념 정리

| 개념 | 한 줄 설명 | 주의 |
|---|---|---|
| Image | 앱 코드 + 실행 파일 + 기본 명령이 포장된 읽기 전용 artifact | 실행 중이 아님, `docker run`으로 container를 만들어야 실행됨 |
| Container | image로 만들어진 실행 중인 process | image 문제와 실행 조건 문제를 섞으면 안 됨 |
| Layer | Dockerfile instruction 하나가 남기는 흔적 | `docker history`로 layer 흐름 추적 가능 |
| Tag | 사람이 읽는 이름표 (`day3`, `1.27-alpine`) | 바뀔 수 있음, `latest`는 재현성 보장 안 함 |
| Digest | registry 기준 content 식별자 | local build image는 비어 있을 수 있음 (오류 아님) |
| Registry | image를 저장·공유하는 장소 | push 전 gate 확인 필요 (secret 유무, public/private) |

### push gate 체크리스트

```text
- image context에 .env/token/개인 파일이 들어가지 않았는가?
- repository가 public인지 private인지 아는가?
- tag 이름이 수업/버전/용도를 설명하는가?
- credential이 README나 screenshot에 남지 않는가?
```

### `docker history` 기대 패턴 해석

```text
IMAGE    CREATED BY                                SIZE
<layer>  CMD ["nginx" "-g" "daemon off;"]         0B
<layer>  EXPOSE map[80/tcp:{}]                    0B
...
```

nginx가 foreground로 실행되는 기본 명령과 80번 container port 정보가 layer에 기록되어 있다. 우리가 만든 image에서는 `COPY index.html`, `COPY styles.css` 흔적이 보여야 앱 파일이 image에 들어갔다는 증거가 된다.

### tag mutable 문제 - 롤백과 분쟁

tag는 덮어쓸 수 있다. `app:v1.0`에 새 image를 push하면 이전 image는 어디 있는지 아무도 모르게 된다. digest를 미리 기록해뒀으면 `image@sha256:...`로 되돌릴 수 있지만, 기록이 없으면 롤백 불가다.

개발자와 충돌이 생기는 전형적인 패턴:

```text
1. 운영팀: app:stable = 어제 검증한 버전이라고 인식
2. 개발팀: 테스트 중에 app:stable에 새 image push
3. 운영팀: 재시작했더니 전혀 다른 버전이 뜸
4. 서로 "내가 바꾼 거 아님" 상태
```

이것을 막는 방법:

| 방법 | 설명 |
|---|---|
| 날짜+commit hash tag | `app:20260619-abc1234` — 덮어쓸 이유가 없어짐 |
| registry immutable tag 설정 | 같은 tag로 재push를 아예 막음 (ECR, Artifact Registry 지원) |
| digest 기록 | push 후 digest를 README나 배포 기록에 남겨 롤백 근거로 씀 |

### layer cache 무효화 전파

Docker는 Dockerfile을 위에서 아래로 실행하다가 **캐시가 깨지는 순간부터 아래를 전부 새로 실행**한다. `WORKDIR` 자체는 캐싱되지만, 그 아래 `COPY`에서 파일이 하나라도 바뀌면 이후 layer가 전부 새로 실행된다.

나쁜 예 — 소스코드가 바뀔 때마다 `npm install`을 새로 실행:

```dockerfile
COPY . .          # 소스 하나라도 바뀌면 캐시 깨짐
RUN npm install   # 매번 새로 실행됨
```

좋은 예 — `package.json`이 안 바뀌면 `npm install` 캐시 재사용:

```dockerfile
COPY package.json .   # 의존성 파일만 먼저 (잘 안 바뀜)
RUN npm install       # package.json 안 바뀌면 캐시 재사용
COPY . .              # 소스코드는 나중에 (자주 바뀜)
```

핵심 원칙: **바뀌는 빈도가 낮은 것을 위에, 높은 것을 아래에.**

### 흔한 오해

- `docker history`에 `<missing>` → 오류 아님. registry에서 pull한 image는 중간 layer 정보가 로컬에 없어서 표시됨
- `RepoDigests`가 비어 있음 → 오류 아님. registry에 push/pull되지 않은 local build image의 정상 상태
- `docker ps`에서 `Up` → 서비스 정상 아님. HTTP verify까지 해야 납품 기준

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
