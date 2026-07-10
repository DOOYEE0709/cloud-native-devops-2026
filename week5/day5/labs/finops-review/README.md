# W5D5S4 FinOps Review Dashboard Lab

AWS Console에서 비용 후보를 찾고 cleanup action을 결정한다.

## Dashboard Template
| Service | Resource | Region | Owner/Purpose tag | Cost evidence | Status | Action | Recheck |
|---|---|---|---|---|---|---|---|
| Budget |  | global |  | threshold/alert |  |  |  |
| Cost Explorer |  | global |  | service/group/filter |  |  |  |
| EC2/EBS |  |  |  | running/stopped/volume/snapshot |  |  |  |
| ELB |  |  |  | load balancer/target group |  |  |  |
| ECS/App Runner/ECR |  |  |  | service/image |  |  |  |
| S3 |  |  |  | bucket/object/version |  |  |  |
| RDS |  |  |  | instance/snapshot |  |  |  |
| CloudWatch |  |  |  | log group/alarm/dashboard |  |  |  |
| Secrets Manager/SSM |  |  |  | secret/parameter |  |  |  |

Status는 `Delete`, `Stop`, `Retain`, `Follow-up`, `Not found` 중 하나로 쓴다.

## Console Steps
1. Billing -> Budgets에서 threshold와 alert 상태를 기록한다.
2. Cost Explorer에서 이번 달, Group by Service로 본다.
3. 비용 데이터가 아직 없으면 데이터 지연이라고 적고 service inventory로 넘어간다.
4. EC2, EBS, ELB, ECS/App Runner, ECR, S3, RDS, CloudWatch, Secrets Manager를 순서대로 확인한다.
5. 남기는 resource는 owner, purpose, cleanup date를 적는다.

## Pass Criteria
- Budget 또는 접근 불가 사유가 있다.
- Cost Explorer 기준이 있다.
- service별 비용 후보가 있다.
- 삭제/중지/유지 결정이 있다.
- retained resource에 owner와 cleanup date가 있다.
