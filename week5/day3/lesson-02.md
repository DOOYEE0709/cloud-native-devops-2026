# 2교시: ECR 실습

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① (build 대신 pull) `docker image pull hello-world:latest` | Status: Downloaded newer image (`hello-world:latest`) — Dockerfile build 대신 공개 이미지로 대체 |
| ② (tag) `docker image tag hello-world:latest 476140239099.dkr.ecr.ap-northeast-2.amazonaws.com/test-web:test-web` | OK (Account Number=`476140239099`, repo=`test-web`, tag=`test-web`) |
| ③ (push) `docker push 476140239099.dkr.ecr.ap-northeast-2.amazonaws.com/test-web:test-web` | `58dee6a49ef1: Pushed` / digest `sha256:5099...b23e` size 1027 / ⚠️ Info: multiplatform 중 **single-platform만 push됨** |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| push가 실패하면 auth/build/tag/push 중 어디부터 보나? | 증상별로. login/token 에러 → **auth**(IAM 권한·Region), Dockerfile 에러 → **build**, repository not found/wrong URI → **tag**(URI·account·Region), denied/network → **push**(권한·repo·Docker daemon) |
| `latest` 대신 `v1`/`v2`를 쓰는 이유는? | 어떤 image가 실행 중인지 **증명·추적** 가능하고 **rollback 기준**이 생김. `latest`는 어느 시점 image인지 나중에 증명하기 어렵다 |
| ECR URI의 구성 요소는? (account/region/repo) | `<account-id>.dkr.ecr.<region>.amazonaws.com/<repository-name>` — 예: `476140239099.dkr.ecr.ap-northeast-2.amazonaws.com/test-web` |

## notes

- **ECR URI 구조**: `<account-id>.dkr.ecr.<region>.amazonaws.com/<repository-name>`
  - 예: `123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/paperclip-w5d3-app`
- **ECR 로그인 명령어 뜯어보기**: `aws ecr get-login-password ... | docker login --username AWS --password-stdin <ECR endpoint>`
  - `aws ecr get-login-password --region ...` → ECR에서 **임시 인증 password(token)** 를 받아 stdout으로 출력 (12시간 유효)
  - `|` (파이프) → 그 token을 화면에 안 띄우고 바로 다음 명령으로 넘김 (credential 노출 방지)
  - `docker login --username AWS` → ECR은 사용자명이 **항상 `AWS`** 로 고정
  - `--password-stdin` → password를 인자로 직접 안 쓰고 **stdin으로 받음** (shell history에 token 안 남김)
  - `<account>.dkr.ecr.<region>.amazonaws.com` → 로그인 대상 **ECR registry 주소** (repo 이름 없이 registry까지만)
  - 한 줄: **"임시 token 받아서(get-login-password) → docker에게 그 token으로 이 registry에 로그인시켜라(docker login)"**
- **Push 흐름 (외우지 말고 단계로)**: authenticate → build → tag(ECR URI로) → push → verify
- **단계별 실패 지점**:
  - auth 실패(login denied/token error) → AWS CLI auth, IAM 권한, Region
  - build 실패(Dockerfile error) → local docker build log
  - tag 실패(repository not found/wrong URI) → ECR URI/account/Region
  - push 실패(denied/network) → 권한, repository, Docker daemon
- **Tag 전략**: `latest`는 편하지만 어떤 image가 실행 중인지 증명 약함
  - `v1`/`v2`(변경 전후 구분) · commit SHA(CI/CD 연결) · digest(가장 엄격)
- **Credential hygiene**: `get-login-password` 출력·token을 screenshot/README/배움일기에 남기지 말 것
- **비용/보존**: ECR image도 저장 비용. 유지하면 lifecycle policy나 삭제 예정일 남기기
- 흔한 실패 3개: ① Region 달라 repo 못 찾음 ② docker login 인증 안 됨 ③ local image를 ECR URI로 re-tag 안 함

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
