# 6교시: 실습 도구 선택 - kind 기준

## 핵심 정리

### 이번 과정 기준 = kind로만 통일
- **kind** = Kubernetes **IN** Docker. Docker 위에 K8s node container를 만든다.

| 작업 | 명령 |
|---|---|
| cluster 생성 | `kind create cluster --config ...` |
| cluster 삭제 | `kind delete cluster --name ...` |
| 설치 검증 | `kind version`, `kind get clusters`, `kubectl get nodes` |

### 왜 kind인가 (학생 환경이 섞여 있어서)
- 환경: Windows+WSL+Docker Desktop / macOS+Docker Desktop / Linux CLI 경험 편차.
- kind는 Docker만 있으면 동일하게 돌아서 **수업 표준화가 쉬움.**

| 선택 이유 | 설명 |
|---|---|
| 생성/삭제 쉬움 | `kind create/delete cluster` 한 줄 |
| CI 친화적 | GitHub Actions에서도 자주 씀 |
| config file 가능 | cluster 이름·port를 파일로 고정 |
| host 오염 적음 | system service를 host에 안 남김 |
| Day5 실습 충분 | Pod/Deployment/Service 학습 가능 |

### kind의 한계 (운영 cluster와 다름)
| 한계 | 의미 |
|---|---|
| node가 Docker container | 실제 cloud VM node와 네트워크/스토리지 차이 |
| LoadBalancer 제한 | cloud LB가 자동 생성 안 됨 |
| production용 아님 | 운영 simulation 아님, **학습/테스트용** |
| Docker resource 의존 | Docker Desktop 메모리/CPU 부족 시 불안정 |

### 수업용 kind config 핵심
```yaml
kind: Cluster              # kind cluster 설정 파일
name: paperclip-week3      # cluster 이름
role: control-plane        # 이 단일 node가 control plane 역할
```
- node image는 **고정 안 함** (학생별 kind version 달라서 → 기본 image로 호환성 ↑). 운영/CI에선 `kindest/node` image를 pinning.
- `role: control-plane` = 이 Docker container가 control plane node 역할. 오늘은 **단일 control plane으로 단순화**(설치·개념 우선).

### 오늘 multi-node 안 하는 이유
- Day4 목표 = **cluster 개념 + 설치 안정화** (scheduling/taint/network는 나중).
```text
Day4: single-node kind cluster
Day5: Pod/Deployment/Service
Week4: K8s object·운영 패턴 확장
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| selected tool은? | kind (Kubernetes IN Docker) |
| why kind? | Docker만 있으면 동일하게 동작 → 환경 섞여도 수업 표준화 쉬움, 생성/삭제 간편, CI 친화 |
| kind 한계는? | node가 Docker container라 실제 VM과 차이, LoadBalancer 제한, production용 아님 |
| config file path는? | `week3/day4/labs/kind-cluster/kind-config.yaml` |

## notes

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
