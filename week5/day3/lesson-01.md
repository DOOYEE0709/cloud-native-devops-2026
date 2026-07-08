# 1교시: Day2 요약 + 컨테이너 실행 서비스 매핑

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| ECR에 push하면 서비스가 실행되는가? | 아니오. ECR은 image **저장소**일 뿐이다. 실행은 ECS/App Runner/EKS가 그 image를 **pull해서** 별도로 한다. push 성공 ≠ 배포 성공 |
| desired count와 running count의 차이는? | desired = service가 **유지하려는** task 목표 개수, running = **실제 떠 있는** task 개수. 둘이 안 맞으면 pull 실패·health 실패·리소스 부족 등을 의심 |
| 오늘의 운영 루프 6단계는? (image→...→rollback) | image → service → health → logs → update → rollback (build image → ECR → ECS/App Runner 실행 → health 확인 → logs 관찰 → tag 변경 update → rollback) |

## notes

- Day2: `Browser -> ALB -> Target Group -> EC2 Web Server` (서버 단위 운영)
- Day3: `Docker image -> ECR -> ECS/App Runner -> Health/Logs -> ALB or Service URL` (실행 패키지 표준화)
- **핵심 분리**: Registry(저장) vs Runtime(실행) vs CloudWatch(관찰)
  - ECR = image 저장소 (Docker Hub 같은 private registry) → **저장**
  - ECS = task/service 기반 실행 (K8s Deployment/Service 일부와 비교) → **실행**
  - App Runner = image/source에서 web service로 빠르게 배포 → **실행**
  - EKS = managed Kubernetes (선택 심화, 준비물 많음) → **실행**
  - CloudWatch = logs/metrics/alarm → **관찰**
- 오늘의 운영 루프: `image -> service -> health -> logs -> update -> rollback`
- 흔한 실패 3개: ① ECR push를 배포 성공으로 착각 ② desired vs running count 미구분 ③ logs 위치 모름
- ECS vs App Runner: ALB/target group을 직접 보고 싶으면 ECS, 빠른 public web service면 App Runner

### ECS vs EKS 선택 기준 — "추상화를 누가 책임지나"
- ECS는 "K8s를 못 써서"가 아니라 **"K8s를 운영할 이유/인력이 없어서"** 고르는 경우가 많다 (일부러 선택).
  - AWS에만 있으면 됨, 운영 부담을 AWS에 떠넘김, K8s 전담(플랫폼팀) 없음
- 판단 기준: 운영 인력 / 생태계(Helm·ArgoCD·Istio 필요?) / 락인 감수 / 팀 규모
- **"개발자 많으면 ECS"는 오히려 반대인 경우가 흔함** — 규모에 따라 수단이 갈린다:
  - 소규모·인프라 전담 없음 → **ECS / App Runner** (AWS가 추상화해줌)
  - 개발자 수백·여러 팀 → 보통 **EKS + 내부 플랫폼**. 플랫폼팀이 EKS 위에 셀프서비스(ArgoCD/내부 PaaS)를 깔고, 개발자는 manifest만 던짐 → EKS 복잡함을 플랫폼팀이 가려줌
- 한 줄: **AWS에 추상화를 맡기면 ECS/App Runner, 우리 플랫폼팀이 K8s 위에 직접 쌓으면 EKS**

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
