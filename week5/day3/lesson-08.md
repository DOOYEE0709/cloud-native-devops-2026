# 8교시: 구름 EXP 배움일기

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| W5D3의 진짜 산출물은? | 실행된 container **URL 하나가 아니라** image→service→health→logs→metrics→rollback→cleanup이 **연결된 운영 evidence**. "됐다"가 아니라 각 단계의 값이 남아야 함 |
| cleanup에서 가장 자주 빠뜨리는 것은? | **service만 삭제하고 ECR image/repository와 ALB를 남김**. ECR·ECS/App Runner·ALB·CloudWatch를 **각각** 확인해야 함 |
| ALB를 꼭 삭제해야 하는 이유는? | ALB는 **존재만으로 과금**됨. target group과 함께 삭제. desired count 0만으로는 ALB 비용이 안 사라짐 |
| ECR image도 정리 대상인가? | 예. image가 계속 쌓이면 **storage 비용**. Day4 이후 쓸 게 아니면 삭제하거나 retention/lifecycle 정책 | 
| EKS를 만들었다면 cleanup 포인트는? | cluster/node뿐 아니라 **load balancer, log, kubeconfig context**까지. 특히 context가 남으면 **다른 cluster를 오조작**할 위험 |
| CloudWatch Logs는 어떻게 정리하나? | log group에 **retention**을 걸거나 삭제. 무기한 보존은 비용보다 관리 부채 |
| Day4로 넘어가는 핵심 질문은? | container가 실행되면 곧 **data와 secret** 문제 — DB endpoint는 어디서, password는 env에 넣어도 되나, S3를 public으로 열어야 하나, private RDS에 app은 어떻게 연결하나 |

## notes

- **D3 배움일기의 핵심**: URL 하나가 아니라 **운영 루프 전체**를 남긴다 — ECR image가 어떤 tag로 있고, 어떤 service가 그 image를 실행하며, health는 어디서 보고, log group은 어디이며, 문제 시 어떤 revision으로 돌아갈지까지 연결
- **구조**: `ECR image → ECS/App Runner service → Health / CloudWatch logs → (배움일기) → Cleanup audit → Day4(Storage/DB/Secret)`
- **cleanup 판단 표**:
  | 대상 | 삭제/유지 판단 |
  |---|---|
  | ECR repository | Day4 이후 안 쓰면 삭제 또는 retention/lifecycle 계획 |
  | ECS service | desired count 0 또는 delete |
  | ECS cluster | 실습용이면 delete |
  | App Runner service | pause/delete 또는 유지 사유 |
  | EKS cluster/node | 생성했다면 삭제 완료 또는 유지 사유 |
  | kubeconfig context | 다른 cluster 오조작 방지 위해 context 확인/삭제 |
  | ALB/TG | ECS 연결 실습 후 삭제 (존재만으로 과금) |
  | CloudWatch Logs | retention 설정 또는 삭제 |
  | IAM role | 실습용이면 잔여 권한 확인 |
- **Day3 → Day4 질문 연결**:
  | 오늘 질문 | Day4 질문 |
  |---|---|
  | image는 어디서 가져오는가 | app data는 어디에 저장하는가 |
  | env는 어디서 넣는가 | secret은 어디에 보관하는가 |
  | service health는 어떻게 보는가 | database 연결 실패를 어떻게 분석하는가 |
  | logs는 어디서 보는가 | storage/database 비용은 어떻게 통제하는가 |
- **좋은 산출물 예시**:
```markdown
Image: paperclip-w5d3-app:v2 in ECR
Service: ECS service desired=1 running=1
Health: target healthy
Logs: /ecs/paperclip-w5d3-app stream checked
Metric: ALB 5xx candidate alarm
Rollback: previous task definition revision 3
Cleanup: service deleted, ALB deleted, log retention 7 days
```
- 흔한 실패 3개:
  - ① service를 삭제하지 않음 (desired 0만 하고 방치)
  - ② **ECR image가 계속 쌓임** / ALB를 남겨 과금
  - ③ **EKS context가 남아** 다른 cluster를 조작
- **한 줄 요약**: W5D3의 산출물은 실행된 container URL이 아니라 **image·service·health·logs·metrics·cleanup이 연결된 운영 evidence**다

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
