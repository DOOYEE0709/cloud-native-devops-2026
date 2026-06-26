# 8교시: 개인 Repo Docker Hub Push 회고

## 실습 확인 기록

> 회고 교시. 본인 repo에서 workflow 실행 → Docker Hub push → pull/run까지 직접 수행.

| 명령/확인 | 결과 |
|---|---|
| Docker Hub image | `niceguy6112/w3d3-dockerhub-app` (push 성공) |
| `docker pull` (arm64 Mac) | 기본 pull 실패(amd64만 존재) → `--platform linux/amd64`로 성공 (자세한 건 7교시 Blocker) |
| 로컬 run + `curl /health` | image 정상 실행 확인 |
| workflow run | 성공 (run_id 28226565273, tag push `v0.1.0` 트리거, ubuntu-24.04 runner) |
| step별 시간 분석 | 완료 — 아래 Step Time 표 참고. 최장: Docker Hub push ~7s, Buildx 빌드 ~6s |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 오늘의 큰 흐름 한 줄? | `branch → PR → CI → image push → registry 확인 → deploy` |
| build됨 ≠ pull 가능을 어디서 체감? | arm64 Mac에서 amd64 image pull 실패 → 플랫폼 지정 필요 |
| Secrets가 없으면 어느 step에서 실패? | `Login to Docker Hub` |
| Secrets가 만능이 아닌 이유? | workflow 수정 권한이 넓으면 secret 악용 가능 → protected branch·review·environment approval 병행 필요 |
| 다음 주(K8s)로 어떻게 이어지나? | image tag→Deployment, registry→imagePull, Secrets→K8s Secrets, environment→deploy gate |

## notes

### 오늘(Day3) 요약
- 1교시 Git 이력 모델 / 2교시 개발자 GitHub Flow / 3교시 인프라 GitHub(통제면) / 4교시 branch 전략 / 5교시 PR·merge·revert·tag / 6교시 Actions+로컬 게이트 / 7교시 Secrets·Docker Hub push.

### 핵심 흐름
```text
branch → PR → CI → image push → registry 확인 → deploy
```
- 이 흐름이 다음 주 Kubernetes 배포로 이어짐.

### Kubernetes로 이어지는 연결
- Docker image tag → Deployment image / Docker Hub → imagePull / GitHub Environment → dev·stage·prod deploy gate / protected branch → production manifest 보호 / Actions → kubectl·helm deploy / GitHub Secrets ↔ Kubernetes Secrets 구분.

### 보강 — 멀티 아키텍처 빌드 (arm64 대응)
- 배경: `v0.1.0`은 amd64 runner에서 단일 빌드 → Apple Silicon(arm64) Mac에서 그냥 pull 시 `no matching manifest`. 임시로 `--platform linux/amd64`로 우회했음.
- 근본 해결: workflow에 두 가지 추가.
  - `docker/setup-qemu-action@v3` (buildx 앞) — amd64 runner에서 arm64 에뮬레이트.
  - 최종 push 단계에 `platforms: linux/amd64,linux/arm64` — 두 아키텍처를 manifest list로 push.
  - 주의: DAST용 `Build local image for DAST`(`load: true`)는 단일 플랫폼만 가능 → amd64 그대로 유지(멀티는 push 단계에만).
- 효과: 새 tag로 다시 돌리면 amd64+arm64 모두 올라가, arm64 Mac에서 `--platform` 없이 그냥 pull 가능.
- 비용: arm64는 에뮬레이션이라 빌드 시간↑.
- 적용 버전: app 코드 변경 없이 빌드/배포 방식만 개선 → SemVer PATCH인 `v0.1.1` 권장. (재배포는 새 tag push 필요)

### 구름 EXP 배움일기 (W3D3S8)
```markdown
# W3D3S8 Learning Journal
- personal repo URL: https://github.com/DOOYEE0709/cloud-native-devops-2026
- workflow file path: .github/workflows/dockerhub-publish.yml
- Docker Hub image: dooyee0709/w3d3-dockerhub-app
- Docker Hub visibility: public
- image tag: 0.1.0 / latest
- private pull auth: (private면 docker login 필요)
- pull/run result: --platform linux/amd64 지정 후 정상

## Step Time  (run #1, cold build / 로그 타임스탬프 기준, run_id 28226565273)
| Step | Time | Note |
|---|---:|---|
| Checkout | ~1.3s | repo fetch (depth=1) |
| Prepare metadata | <1s | version 계산 |
| Unit test | ~0.1s | `Ran 1 test in 0.000s` |
| SAST | <1s | grep 스캔, sast-scan-ok |
| Set up Buildx | ~3.4s | buildkit 부팅 + moby/buildkit pull |
| Docker build (DAST용) | ~6s | 이 중 cache export 3.3s |
| DAST | ~1.2s | container health, dast-health-check-ok |
| Login Docker Hub | ~0.5s | Login Succeeded |
| Docker Hub push | ~7s | push layers/manifest, 가장 김 |
| Show pull cmd | <1s | echo |
| (전체 job) | ~20s | + summary/cleanup |

## Reflection
- 가장 오래 걸린 step: Docker Hub push(~7s)와 Buildx 빌드(~6s).
- 그 이유: 첫 실행이라 gha cache를 채우는 중(cache export 3.3s) + buildkit 이미지 pull + registry로 layer push(network).
- cold build vs warm build 차이: push 빌드에서 `WORKDIR`/`COPY`가 CACHED로 떠 gha cache가 먹힘 → 다음(warm) 실행은 더 빠를 것으로 예상.
- 자동화가 수동 배포보다 나았던 점: unit→SAST→build→DAST→push가 YAML 한 번으로 일관 실행, 로그로 단계·시간이 그대로 남음.
- Secrets 장점 / 조심할 점: 장점=token을 코드에 안 둠(로그에 `***` 마스킹). 조심=값 재확인 불가·rotation·workflow 권한 관리.
- 보강하고 싶은 점: 멀티 아치 빌드(arm64 포함), `latest` 외 version tag 전략, warm build 시간 비교.
- Kubernetes question: 이 image tag를 Deployment에 어떻게 연결하고, Docker Hub pull용 imagePullSecret을 어떻게 둘지.
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
