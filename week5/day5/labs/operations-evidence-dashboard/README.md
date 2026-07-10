# W5D5S2 Operations Evidence Dashboard Lab

AWS Console evidence를 질문별 dashboard로 정리한다.

## Dashboard Template
| Question | AWS Console path | Resource | Evidence value | Decision | Next action | Screenshot? |
|---|---|---|---|---|---|---|
| Is the service healthy? |  |  |  |  |  |  |
| What happened in the app/runtime? | CloudWatch -> Log groups |  |  |  |  |  |
| What changed in metrics? | CloudWatch -> Metrics |  |  |  |  |  |
| Who changed AWS config? | CloudTrail -> Event history |  |  |  |  |  |
| What might still cost money? | Cost Explorer or service inventory |  |  |  |  |  |
| What should go into the final packet? | local evidence folder |  |  |  |  |  |

## Console Steps
1. Pick one representative Week 5 resource.
2. Open its health/status screen first.
3. Find one related CloudWatch log group or metric.
4. Find one CloudTrail event from today's lab.
5. Check Cost Explorer or service inventory for remaining cost candidates.
6. Write the decision each evidence supports.
7. Mark screenshots as `keep`, `redact`, or `discard`.

## CloudTrail Events To Try
| Event name | Meaning |
|---|---|
| `AuthorizeSecurityGroupIngress` | SG inbound rule added |
| `RevokeSecurityGroupIngress` | SG inbound rule removed |
| `RunInstances` | EC2 instance launched |
| `CreateLoadBalancer` | load balancer created |
| `PutBucketPolicy` | S3 bucket policy changed |
| `ConsoleLogin` | Console login event |

## Pass Criteria
- health evidence exists.
- log or metric evidence exists.
- CloudTrail evidence exists.
- cost or cleanup evidence exists.
- every evidence row has a decision.
