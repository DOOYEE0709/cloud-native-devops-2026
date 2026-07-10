# W5D5S7 Portfolio Packet Lab

Week 5 AWS 운영 evidence를 README 중심의 포트폴리오 패킷으로 묶는다.

## Portfolio README Template
```markdown
# Week 5 AWS Operations Portfolio

## Overview

## Architecture

## Evidence Index
| Area | File/Link | AWS screen | Decision supported |
|---|---|---|---|

## Incident Note

## Security Review

## FinOps Review

## Operations Runbook

## Cleanup/Handoff

## Remaining Risks
```

## Evidence Categories
| Category | Include |
|---|---|
| Normal operation | endpoint, health, logs, metrics |
| Incident | symptom, evidence, action, verification |
| Security | IAM, SG, S3, CloudTrail |
| Cost | Budget, Cost Explorer, inventory |
| Cleanup | deleted proof, retained list |

## Redaction Checklist
- account email is hidden
- access key and secret values are absent
- token/password/MFA code are absent
- billing payment details are absent
- screenshots explain a decision, not just a screen

## Pass Criteria
- README links all evidence.
- architecture is visible.
- incident/security/cost/cleanup are all represented.
- sensitive values are removed.
- retained resources have reasons.
