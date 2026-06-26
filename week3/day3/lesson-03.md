# 3교시: 인프라 엔지니어의 GitHub 관리 전략

## 실습 확인 기록

> 3교시도 개념 중심 (셸 실습 없음).

| 명령/확인 | 결과 |
|---|---|
| 인프라 엔지니어에게 GitHub란? | 코드 저장소 이상 — **배포 통제면(control plane)** |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 개발자와 인프라 엔지니어의 주요 변경 차이? | 개발자=application code / 인프라=workflow·Dockerfile·IaC·manifest |
| 인프라 엔지니어의 주요 위험? | 배포 실패, secret 노출, 잘못된 리소스 변경 |
| protected branch로 무엇을 막나? | main/prod 직접 push, 미검토 merge |
| Docker Hub push에 필요한 secret? | `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`(password 대신 access token) |
| audit 관점에서 GitHub에 남겨야 할 것? | 누가·어떤 변경을·어떤 검증 거쳐·어느 환경에 반영했는지 |

## notes

### 인프라 GitHub 관리 대상
- `.github/workflows`(자동화 실행 주체), Dockerfile(secret 포함·image size), Terraform(plan/apply 승인·state 보호), K8s manifest(namespace·image tag·secret 참조), branch protection, repository secrets.

### Protected branch 기준
- require pull request / require approvals / require status checks / restrict who can push / require conversation resolved.

### Secret 관리 — 절대 금지 3가지
```text
workflow에서 echo로 secret 출력 금지
Dockerfile에 secret COPY 금지
.env commit 금지
```
- Docker Hub push secret: `DOCKERHUB_USERNAME`(namespace), `DOCKERHUB_TOKEN`(access token).

### Evidence Note
```markdown
# W3D3S3 Infra GitHub Strategy
- protected branch: main 직접 push 차단, PR 필수
- required checks: lint/test/build, SAST
- secrets: DOCKERHUB_USERNAME, DOCKERHUB_TOKEN
- workflow owner: 인프라 담당 (.github/workflows)
- audit evidence: workflow log, image tag, PR 이력
```

### 강의 인사이트 — AI 생성물과 엔지니어의 몫
- 요즘 AI가 Dockerfile / GitHub Actions workflow **초안은 금방** 만들어줌. 단, **품질 보장은 못 함.**
- 엔지니어 역할이 "처음부터 작성" → **"검증·판단"** 으로 이동.
- AI가 놓치기 쉬운 것 → 사람이 봐야 함: secret 노출(echo/COPY), image 비대, latest tag 남발, 과도한 토큰 권한, build context 민감파일, 회귀 미검증.
- 핵심: AI=빠른 초안 / 품질·보안·정책 적합성 판단=사람 몫. → 인프라 엔지니어가 GitHub를 배포 통제면으로 운영하는 이유와 연결.

### 강의 인사이트 — 자동화 원칙
- 원칙: **자동화 가능한 반복·검증 작업은 최대한 자동화하되, 되돌리기 어렵거나 위험한 결정은 사람 승인 게이트를 남긴다.** ("무조건 다 자동화" 아님)
- 자동화 이유: 반복 제거 / 실수 감소 / 재현성 / 추적성(workflow log) / 속도.
- 자동화 OK: build·test·lint·SAST·image push, 반복 인프라 plan, 알림/로그.
- 사람 게이트 유지: prod 배포 승인, terraform apply, DB 마이그레이션·삭제 등 비가역 작업, 정책·보안 최종 판단.
- protected branch / require approvals 가 바로 "의도적으로 사람을 끼워넣는" 장치. → AI=빠른 초안, 판단=사람 몫 인사이트와 일관.

### 메모 — lesson-03 이미지
- (강의자료 갱신됨) 이미지가 `lesson-03-infra-github-governance.png`로 교체됨 = **인프라 GitHub 관리 전략** 다이어그램.
- 본문과 일치: IaC 저장소 구조(`.github/workflows`·terraform·k8s manifest), protected branch & required checks, secrets, CI/CD 파이프라인.
- (참고) 갱신 전 이미지는 queue/redis 운영(동기 vs 비동기) 그림이었음 — 그땐 본문과 별개 주제였으나 이제 교체되어 일치.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
