# W5D5S5 Incident Drill Lab

작은 장애를 주입하거나 시뮬레이션하고 evidence 기반 incident note를 만든다.

## Incident Note Template
```markdown
# Incident note
- Scenario:
- Account/Region:
- Symptom:
- Scope:
- Recent change:
- Evidence:
- Suspected boundary:
- Action:
- Verification:
- Follow-up/cleanup:
```

## Scenario A: Security Group HTTP Failure
1. 정상 상태에서 `curl -m 5 -i http://<endpoint>/` 결과를 기록한다.
2. EC2 -> Security Groups에서 HTTP 80 inbound rule을 임시 제거한다.
3. 같은 curl 명령으로 실패를 기록한다.
4. CloudTrail에서 `RevokeSecurityGroupIngress`를 찾는다.
5. HTTP rule을 복구한다.
6. 같은 curl 명령으로 정상 응답을 기록한다.

## Scenario B: No-Change Simulation
실제 변경이 어려우면 아래 중 하나를 고른다.

| Symptom | Evidence 1 | Evidence 2 | Boundary |
|---|---|---|---|
| ALB 5xx | Target health | CloudWatch logs | runtime/network |
| S3 AccessDenied | object URL | bucket Permissions | data/security |
| app update failed | service events | CloudTrail | runtime/change |
| cost surprise | Cost Explorer | resource inventory | cost/cleanup |

## Pass Criteria
- symptom과 scope가 구분된다.
- recent change evidence가 있다.
- action 전후를 같은 기준으로 비교한다.
- cleanup 또는 follow-up이 있다.
