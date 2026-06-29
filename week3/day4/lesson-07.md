# 7교시: WSL/macOS kubectl, kind 설치

## 핵심 정리

### 3개 도구 역할 (셋 중 하나라도 빠지면 실습 막힘)
| 도구 | 역할 |
|---|---|
| **Docker** | kind node container를 실행하는 **기반** |
| **kubectl** | Kubernetes API server에 요청하는 **CLI(리모컨)** |
| **kind** | Docker 위에 local cluster를 **만드는** 도구 |
- 3교시 notes 비유 그대로: kind=설치기사, cluster=본체, kubectl=리모컨. Docker는 그 밑바닥.

### 공통 확인 명령
```bash
docker version
docker ps
kubectl version --client=true
kind version
```

### WSL 기준
- 먼저 **Docker Desktop + WSL integration** 확인 (`docker version`, `docker ps`).
- kubectl (Linux amd64):
  ```bash
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl
  kubectl version --client=true
  ```
- kind (Linux amd64):
  ```bash
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
  chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
  kind version
  ```
- ⚠️ **ARM64 Linux**면 binary URL이 다름 → 공식 문서에서 architecture 확인.

### macOS 기준 (Homebrew)
```bash
brew install kubectl kind
kubectl version --client=true
kind version
docker version
```
- Apple Silicon/Intel 차이는 brew가 보통 처리. `which kubectl`, `which kind`로 PATH 확인.

### 설치 실패 대응
| 증상 | 원인 후보 | 첫 확인 |
|---|---|---|
| `docker ps` 실패 | Docker daemon 미실행 | Docker Desktop 실행 |
| `kubectl: command not found` | 설치 안 됨/PATH | `which kubectl` |
| `kind: command not found` | 설치 안 됨/PATH | `which kind` |
| `permission denied` | 실행 권한 없음 | `chmod +x` |
| curl 다운로드 실패 | 네트워크/프록시 | browser로 URL 확인 |

### 설치 성공 판단 기준
- 긴 출력 말고 **핵심 line만** 기록: OS / Docker 도달 여부 / kubectl client version / kind version.
- 수업 명령이 실패하면 **공식 문서 우선** (kubectl·kind 최신 버전/URL은 바뀔 수 있음).

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Docker 역할은? | kind node container를 실행하는 기반 |
| kubectl 역할은? | K8s API server에 요청하는 CLI |
| kind 역할은? | Docker 위에 local cluster를 만드는 도구 |
| 설치 성공 판단은? | version 출력 + 실제 cluster 생성 가능 여부 |
| 공통 확인 명령은? | `docker version/ps`, `kubectl version --client=true`, `kind version` |

## notes

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
