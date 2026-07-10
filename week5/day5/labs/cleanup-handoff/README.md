# W5D5S8 Cleanup Handoff Lab

Week 5 AWS resource를 service별로 닫고 Terraform 보강 수업으로 넘길 내용을 정리한다.

## Final Inventory Template
| Service | Resource | Region | Status | Action | Proof | Retain reason | Cleanup date |
|---|---|---|---|---|---|---|---|
| EC2 instance |  |  |  |  |  |  |  |
| EBS volume/snapshot |  |  |  |  |  |  |  |
| Load Balancer/Target Group |  |  |  |  |  |  |  |
| ECS/App Runner |  |  |  |  |  |  |  |
| ECR repository |  |  |  |  |  |  |  |
| S3 bucket/object/version |  |  |  |  |  |  |  |
| RDS instance/snapshot |  |  |  |  |  |  |  |
| CloudWatch log/alarm/dashboard |  |  |  |  |  |  |  |
| Secrets/Parameters |  |  |  |  |  |  |  |
| IAM policy/access key |  | global |  |  |  |  |  |

Status는 `Deleted`, `Stopped`, `Retained`, `Not found`, `Need owner decision` 중 하나로 쓴다.

## Handoff Note Template
```markdown
# Terraform handoff
- Account/Region:
- Candidate resources to codify:
- Resources intentionally excluded:
- Security rules to avoid:
- Cost controls to include:
- Secrets handling note:
- Next owner:
```

## Pass Criteria
- service별 inventory가 있다.
- 삭제 후 재조회 proof가 있다.
- retained resource에 owner/purpose/cleanup date가 있다.
- 남은 public exposure가 기록되어 있다.
- Terraform handoff candidate가 있다.
