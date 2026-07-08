# 3교시: ECS 또는 App Runner 맛보기

> ⚠️ **먼저 짚을 것**: 2교시에서 push한 `hello-world`는 **web server가 아니다** (한 번 출력하고 종료). App Runner/ECS는 지정 port에서 HTTP를 **listen하는 web app**을 기대하므로 hello-world는 health check가 실패한다. 실제 실행을 보려면 `nginx` 같은 web 이미지를 하나 ECR에 올려서 쓰는 게 낫다.

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| ECR image → web endpoint까지 어떻게 실행되나? | image가 registry(저장)에 있고, ECS task/App Runner service(실행)가 그 image를 **pull → 지정 port로 실행 → health check 통과 → endpoint 노출**. 저장과 실행은 분리돼 있다 |
| desired count 0이면 정상 서비스인가? | 아니오. desired=0이면 유지하려는 task가 없어 **running task도 0** → endpoint 죽음. 정상은 desired와 running이 같고 health OK인 상태 |
| App Runner는 managed라 관찰이 필요 없나? | 아니오. managed여도 **health·logs·deployment status는 여전히 내 책임**. build/deploy/app log를 봐야 실패 원인을 안다 |

## notes

- **ECS 실행 단위 계층**: `ECR image → Task Definition → Service → Desired Count → Logs/Health`
  - Cluster = 논리적 묶음 / Task Definition = image·CPU/mem·port·env·log config / Service = desired count·deployment·LB / Task = 실제 실행 단위
- **App Runner 실행 단위**: Source(ECR image/repo) → Port → Service URL(public) → Deployment → Logs(build/deploy/app)
- **Port mapping이 핵심**: container가 listen하는 port와 서비스가 노출하는 port가 맞아야 health check·traffic 성공 (nginx=80)
- **선택 기준**:
  - IAM/ECS 권한 충분 + ALB 연결까지 보고 싶음 → ECS
  - 빠른 web service + logs만 보고 싶음 → App Runner
  - 비용/권한 불안정 → Console 시뮬레이션 + 개념 evidence (단, 실제 생성/시뮬레이션을 배움일기에 **구분해서** 기록)
- **service 생성 ≠ 정상**: desired/running count, deployment status, health, logs를 **함께** 봐야 함
- 흔한 실패 3개: ① container port 잘못 설정 ② desired count 0을 정상으로 착각 ③ 생성 후 logs 안 봄

### IAM Role 인증 — DynamoDB에 왜 secret key를 안 넣나
- 코드에 access key/secret key를 **직접 박지 않는 게 정석**. IAM Role로 "이 실행 주체가 누구다"를 증명하면 SDK가 **임시 자격증명**을 자동으로 받아 쓴다.
  - 하드코딩 키 → 유출 시 계정 사고 / IAM Role → 임시 token(자동 만료·갱신)
- **Credential Provider Chain** (SDK/CLI가 이 순서로 credential을 자동 탐색):
  1. 코드에 직접 넣은 키 (비추) → 2. 환경변수(`AWS_ACCESS_KEY_ID`) → 3. `~/.aws/credentials`(`--profile`) → 4. **IAM Role**
- 실행 위치별 DynamoDB/S3 접근 방법:
  - 내 노트북 → `aws configure`로 넣은 프로필 (`~/.aws/credentials`)
  - **EC2** → instance profile(Role) · **ECS task** → task role(Role) · **Lambda** → execution role(Role) → 셋 다 **키 없이** metadata endpoint에서 임시 token 자동 획득
- **ECR 로그인(2교시 `get-login-password`)과 같은 원리**: secret을 꺼내는 게 아니라 IAM 신원으로 **임시 token**을 받아 인증
- 한 줄: **secret key를 넣는 게 아니라, IAM 신원(Role/프로필)으로 임시 자격증명을 자동으로 받아 쓴다** → 키를 코드에 안 두는 게 보안 핵심

### ECS 로그 수집은 opt-in — 안 켜면 로그가 아예 없다
- ECS는 task definition의 **log configuration(awslogs 드라이버)** 을 설정해야 CloudWatch로 로그가 간다. **기본으로 켜지는 게 아니다.**
- 안 켜면: CloudWatch 비용은 덜 나오지만 → **장애 시 볼 로그가 아예 없는** 무서운 상황. 이미 죽은 task는 stdout/stderr를 되살릴 방법이 없다.
- 그래서 task definition 만들 때 `logConfiguration.logDriver=awslogs` + log group을 **처음부터** 지정해두는 게 안전 (사후에 못 되살림).
- 교훈: "비용 아끼려 로그 끔"은 눈 가리고 운영하는 것. 관찰 비용은 장애 대응의 보험이다. → 6교시 CloudWatch Logs와 연결

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
