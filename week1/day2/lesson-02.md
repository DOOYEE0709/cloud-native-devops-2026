# 2교시: GitHub 계정, Git, Python3, VS Code 확인

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Git과 GitHub의 차이를 한 문장으로 설명할 수 있는가? | Git은 내 컴퓨터에서 변경 이력을 관리하는 로컬 CLI 도구이고, GitHub는 repository를 원격에서 공유하고 협업하는 웹 서비스다. |
| Git 설치 확인 기록은 무엇인가? | `git --version` 명령을 실행하고 `git version 2.x.x` 형태의 출력이 나오면 설치된 것이다. command not found면 설치가 안 된 상태다. |
| Python3 설치 확인 기록은 무엇인가? | `python3 --version` 명령을 실행하고 `Python 3.x.x` 형태의 출력이 나오면 설치된 것이다. Windows에서는 `py --version` 또는 `python --version`으로 대체 확인한다. |
| VS Code가 준비되지 않았을 때 막힘 기록을 어떻게 기록해야 하는가? | `code --version`이 실패하면 VS Code GUI에서 `Terminal > New Terminal`을 열어 `pwd`, `git --version`을 확인한다. CLI 미등록과 VS Code 미설치는 다른 상황이다. |
| GitHub에 로그인했으니 Git도 설치된 것인가? | 아니다. GitHub는 웹 서비스이고 Git은 로컬 CLI 도구다. 각각 별도로 확인해야 한다. |
| Python은 나중에 설치해도 되는가? | 아니다. Day3 로컬 서버 실습에서 `python3 -m http.server` 명령이 바로 필요하므로 Day2에서 확인해야 한다. |
| 토큰을 README에 붙이면 인증 문제가 해결되는가? | 아니다. 토큰은 비밀값이다. 공개 repository에 절대 남기지 않는다. 증상만 기록하고 토큰 값은 기록하지 않는다. |

## notes

### 네 도구의 역할 구분

| 도구 | 역할 | 설치 확인 명령 |
|---|---|---|
| GitHub 계정 | 원격 repository 공유, 협업 서비스 | 웹 로그인 확인 |
| Git | 로컬 변경 이력 관리 CLI | `git --version` |
| Python3 | Day3 로컬 정적 서버 실행 도구 | `python3 --version` |
| VS Code | 코드 편집 및 터미널 작업 환경 | `code --version` 또는 GUI 터미널 |

네 도구는 같은 것이 아니다. GitHub 계정이 있어도 Git이 설치되어 있지 않을 수 있고, Python3가 없으면 Day3 `python3 -m http.server` 실습에서 막힌다.

### Python3 설치 방법 (OS별)

| 환경 | 설치 방법 | 설치 후 확인 |
|---|---|---|
| macOS + Homebrew | `brew install python3` | `python3 --version` |
| macOS without Homebrew | python.org에서 macOS installer 다운로드 | `python3 --version` |
| Ubuntu/WSL | `sudo apt update` 후 `sudo apt install -y python3 python3-pip` | `python3 --version` |
| Windows | python.org installer에서 "Add python.exe to PATH" 체크 후 설치 | `py --version` 또는 `python --version` |

### 확인 명령 절차

```bash
git --version
python3 --version
pwd
code --version
```

`code --version`이 실패하면 VS Code GUI에서 `Terminal > New Terminal`을 열고:

```bash
pwd
git --version
python3 --version
```

### 실패 장면 분류

| 실패 장면 | 먼저 의심할 원인 | 학생용 기록 문장 |
|---|---|---|
| `git: command not found` | Git 미설치 또는 PATH 문제 | "Git 명령을 shell이 찾지 못함" |
| `python3: command not found` | Python3 미설치 또는 PATH 문제 | "Python3 명령을 shell이 찾지 못함" |
| `brew: command not found` | Homebrew 미설치 | "Homebrew가 없어 python.org installer 필요" |
| `code --version` 실패 | VS Code CLI 미등록 | "GUI 터미널에서 대체 확인함" |
| 인증 팝업 반복 | credential/토큰/권한 문제 | "비밀값은 기록하지 않고 증상만 기록함" |

### 이후 주차 연결

Docker, Kubernetes, AWS CLI, Terraform도 모두 같은 방식으로 확인한다. `tool --version`, 현재 경로, 인증 상태, 비밀값 비공개 기준은 이후 모든 주차의 공통 준비 절차다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
