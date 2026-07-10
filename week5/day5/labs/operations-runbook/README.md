# W5D5S6 Operations Runbook Lab

Week 5에서 수행한 Console 작업을 반복 가능한 운영 절차로 작성한다.

## Runbook Template
```markdown
# Runbook: <title>

## Trigger

## Owner

## Preconditions
- Account/Region:
- Required permission:
- Target resource:
- Safety note:

## Normal Baseline

## Evidence Collection
| Step | AWS Console path | Value to check | Normal | Abnormal |
|---|---|---|---|---|

## Decision Table
| Condition | Decision | Action |
|---|---|---|

## Action Steps

## Verification

## Cleanup/Handoff
```

## Recommended Topics
| Topic | Required evidence |
|---|---|
| Web endpoint incident | endpoint, target health, logs, SG, CloudTrail |
| Security exposure cleanup | IAM, SG, S3 Permissions, CloudTrail |
| Cost cleanup | Cost Explorer, EC2, ELB, EBS, S3, RDS, CloudWatch |
| S3 AccessDenied | object URL, bucket policy, Block Public Access |

## Pass Criteria
- trigger와 owner가 있다.
- Console path가 구체적이다.
- 정상/비정상 기준이 있다.
- action 후 verification이 있다.
- cleanup/handoff가 있다.
