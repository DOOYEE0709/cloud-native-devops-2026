# 2교시: Docker 설치 및 실행 확인 - macOS/Linux 경로 분리

## 실습 확인 기록

| 명령/확인 | 설명 | 결과 |
|---|---|---|
| `docker version` | Docker CLI(Client)와 daemon(Server) 버전 및 연결 상태 확인 | ![docker version](assets\lesson-02\docker-version.png) |
| `docker compose version` | Docker Compose 플러그인 설치 여부 및 버전 확인 | ![docker compose version](assets\lesson-02\docker-compose-version.png) |
| `docker run --rm hello-world` | 테스트용 image를 pull해서 실행 후 자동 삭제 — 설치 전체 흐름이 정상인지 확인 | ![docker run --rm hello-world](assets\lesson-02\docker-run-rm-helloworld.png) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| `docker version`에서 Client만 보이고 Server가 없으면 어떤 상태인가? | Docker CLI는 있지만 daemon에 연결되지 않은 상태다. Docker Desktop이 실행 중이 아니거나, Linux에서 daemon이 시작되지 않은 경우다. container는 실행할 수 없다. |
| Docker Desktop 창이 열리면 실습 준비가 끝난 것인가? | 아니다. CLI에서 `docker version`으로 Client와 Server가 모두 보이는지 확인해야 한다. GUI와 daemon 연결은 별개다. |
| Linux에서 Docker Desktop for Linux와 Docker Engine의 차이는? | Docker Desktop for Linux는 자체 Linux VM을 만들고 전용 Docker context를 사용한다. Docker Engine은 host Linux daemon을 직접 사용한다. 둘을 동시에 쓰면 port 충돌이 날 수 있다. |
| password/token/MFA code를 screenshot에 남기면 안 되는 이유는? | 공유된 screenshot에 credential이 포함되면 의도치 않게 노출된다. error message에도 token 일부가 포함될 수 있으므로 마스킹 후 공유한다. |

## notes

### OS별 설치 경로

| OS | 경로 | 확인 명령 |
|---|---|---|
| macOS (Apple silicon / Intel) | Docker Desktop Mac 설치 | `docker version`, `docker compose version` |
| Linux | Docker Desktop for Linux 또는 Docker Engine (Ubuntu) 중 선택 | `docker version`, `systemctl status docker` (Engine) |
| Windows — Docker Desktop | Windows에 Docker Desktop 설치 | `docker version`, `docker compose version` |
| Windows — WSL 내부 | WSL(Linux) 안에 Docker Engine 설치 | WSL 터미널에서 `docker version` |

- macOS는 Apple silicon인지 Intel인지에 따라 설치 파일과 요구사항이 다를 수 있다.
- Linux Engine 경로는 Desktop GUI 없이 daemon/CLI 연결만 확인한다.
- Windows는 Docker Desktop(Windows)과 WSL 내부 Docker(Linux)가 **별개 환경**이다. OS가 달라 호환되지 않으므로, 둘 중 어느 쪽을 쓸지 처음에 명확히 정해야 한다.

설치 가이드: [필수 소프트웨어 설치 가이드](../../docs/software-installation-guide.md)

### 공식 문서 확인 항목

| 항목 | 기록할 내용 |
|---|---|
| 문서 URL | 본인 OS에 맞는 Docker 공식 설치 문서 |
| Mac chip | Apple silicon 또는 Intel |
| 권한 조건 | 앱 실행 권한, 보안 설정, 관리자 권한 필요 여부 |
| Linux 경로 | Desktop for Linux 또는 Engine |
| 설치 후 확인 | `docker version` Client/Server 모두 보임 |

### `docker version` 읽는 법

```text
Client: Docker Engine - Community
 Version: 27.x.x
 ...

Server: Docker Engine - Community
 Engine:
  Version: 27.x.x
  ...
```

- `Client` → terminal에서 실행한 Docker CLI
- `Server` → container를 실제로 관리하는 Docker daemon
- Server 응답 없음 = daemon 미실행 또는 permission 문제

### 보안

| 항목 | 공개 가능 | 공개 금지 |
|---|---|---|
| Docker Hub username | 수업 정책에 따라 가능 | |
| image name/tag | 가능 | |
| password / token / MFA | | 어떤 경우에도 README/screenshot에 남기지 않음 |
| error message | secret 제거 후 가능 | token 일부 포함 시 마스킹 |

### 데몬(daemon)이란

백그라운드에서 계속 실행되면서 요청을 기다리는 프로세스다.

- **CLI** (`docker run ...`) → container 실행을 **요청하는 쪽**
- **daemon** (`dockerd`) → 요청을 받아 **실제로 container를 만들고 관리하는 쪽**

CLI는 손님, daemon은 주방이다. 주방이 닫혀 있으면 주문해도 아무것도 안 된다. `docker version`에서 Server가 안 보이는 상태 = daemon이 꺼져 있는 상태다. Docker Desktop을 열면 daemon이 함께 켜진다.

### container는 왜 항상 Linux 기반인가

Docker container는 거의 항상 Linux 기반 image다.

- Docker Desktop(Windows)도 내부에 Linux VM을 띄워서 그 위에서 Linux container를 실행한다.
- WSL 안의 Docker도 마찬가지로 Linux container를 실행한다.
- 운영 서버(AWS EC2, Kubernetes 등)도 거의 항상 Linux다.

그래서 배포할 때는 어느 쪽에서 빌드했든 동일한 Linux 기반 image가 나온다. **배포 환경에서 차이가 생기지 않는다.**

"호환이 안 된다"는 건 **로컬 개발 환경에서의 문제**다.

- Docker Desktop에서 pull한 image가 WSL Docker에서는 안 보인다.
- 한쪽 daemon에서 실행한 container를 다른 쪽에서 관리하지 못한다.
- 두 Docker가 서로 다른 daemon을 쓰기 때문에 로컬에서 같이 쓰면 혼란스러워진다.

처음에 하나를 골라야 하는 이유는 배포 때문이 아니라, **로컬 작업 환경을 통일**하기 위해서다.

### 흔한 오해

- Desktop 창이 열리면 준비 완료다 → `docker version` Server 연결까지 확인해야 한다.
- Client 정보가 보이면 container 실행이 가능하다 → Server 연결이 없으면 실행은 실패한다.
- 로그인 실패 = Docker 설치 실패 → 설치/daemon 연결과 Hub 인증은 다른 문제다.
- WSL Docker와 Docker Desktop은 나중에 배포할 때 OS가 달라진다 → 둘 다 Linux container를 만들므로 배포 환경은 같다.
- Windows에서 host mode를 쓰면 Windows 네트워크에 직접 붙는다 → WSL 네트워크에 붙는 것이다. Windows까지 닿으려면 WSL 포트 포워딩을 거친다.

## Blocker Log

| 증상 | 확인한 것 | 시도한 공식 문서 |
|---|---|---|
| | | |
