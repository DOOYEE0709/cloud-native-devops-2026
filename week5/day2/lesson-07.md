# 7교시: EC2/ALB 운영 관찰

```bash
# 이 교시 실습 변수
export REGION=ap-northeast-2
export ALB_DNS=my-alb-xxxx.ap-northeast-2.elb.amazonaws.com
export TG_ARN=arn:aws:elasticloadbalancing:...:targetgroup/...
export INSTANCE=i-xxxxxxxxxxxx
export SG=sg-xxxxxxxxxxxx
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① (사용자 증상) `curl -m 5 -i http://$ALB_DNS/` | |
| ② (ALB 상태) `aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[].{State:State.Code,DNS:DNSName}" --output table` | |
| ③ (target health + reason) `aws elbv2 describe-target-health --region $REGION --target-group-arn $TG_ARN --query "TargetHealthDescriptions[].{Id:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason,Desc:TargetHealth.Description}" --output table` | |
| ④ (EC2 status check) `aws ec2 describe-instance-status --region $REGION --instance-ids $INSTANCE --query "InstanceStatuses[].{Inst:InstanceStatus.Status,Sys:SystemStatus.Status}" --output table` | |
| ⑤ (system log) `aws ec2 get-console-output --region $REGION --instance-id $INSTANCE --output text | tail -40` | |
| ⑥ (network gate) `aws ec2 describe-security-groups --region $REGION --group-ids $SG --query "SecurityGroups[].IpPermissions" --output json` | |
| ⑦ (변경 추적 preview) CloudTrail Event history에서 `AuthorizeSecurityGroupIngress` / `RevokeSecurityGroupIngress` 검색 | |
| ⑧ (metric 위치) CloudWatch → ALB/EC2 metric 위치만 확인 (Day3 preview) | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 운영 관찰의 핵심은? | **한 화면의 초록불이 아니라 요청 경로 전체 evidence를 연결**. 사용자 증상 하나에 ALB·target·EC2·SG·app 여러 계층이 숨어 있음 |
| 관찰 순서는? | ① 사용자 증상(curl) ② ALB 상태 ③ **target health+reason** ④ EC2 status check ⑤ network gate(SG) ⑥ app(process/system log) ⑦ 변경 추적(CloudTrail) |
| 503인데 app 문제인가? | 꼭 아님. **target group에 healthy target이 없어서**일 수 있음. target health reason부터 → app code 단정 금지 |
| EC2 public IP는 되는데 ALB만 안 되면? | 그 사이 계층 → **listener / target group / health check / ALB SG**. 둘 다 안 되면 app 또는 EC2 network |
| "갑자기 접속 안 됨"은 어디서? | 누가 **SG를 바꿨는지 CloudTrail**. app log(CloudWatch)가 아니라 **API 변경 이력** |
| CloudWatch vs CloudTrail? | **CloudWatch**=metric/log(상태·성능), **CloudTrail**=**누가 어떤 API 호출**(SG/ALB/EC2 변경 audit). SG rule 변경자는 CloudTrail |
| system log는 언제 보나? | boot/**user data 실패** 확인. user data 실패를 app 문제로 오진하지 않기 위해 |
| evidence 남기는 법? | "아마 SG 문제"로 끝내지 않음. **증상→증거1,2,3→조치→재확인**을 한 세트(incident note) |

## notes

### 관찰 순서 (계층으로 나누기)
```text
1. 사용자 증상   : browser/curl 결과
2. ALB 상태      : active, listener, DNS
3. Target group  : target health, reason   ← 503의 핵심
4. EC2 상태      : running, status checks
5. Network gate  : ALB SG, EC2 SG, route/subnet
6. App 상태      : web server process, user data/system log
7. 변경 추적     : CloudTrail (누가 바꿨나)
```
> ⭐ **사용자 증상 하나 = 여러 계층.** ALB active만 보고 정상이라 하지 말 것. 503은 app일 수도, healthy target 없음일 수도.

### 장애 예시 → 첫 확인
| 사용자 증상 | 가능한 원인 | 첫 확인 |
|---|---|---|
| ALB DNS timeout | ALB SG, subnet, DNS 전파 | ALB SG inbound |
| 503 | healthy target 없음 | **target health reason** |
| EC2 public IP는 됨, ALB 안 됨 | listener/TG/health check | Listener, TG |
| EC2 public IP도 안 됨 | SG/public IP/app | EC2 SG, instance |
| **갑자기** 접속 안 됨 | 누가 SG 변경 | **CloudTrail event** |

### incident note 예시 (evidence 세트)
```markdown
증상: ALB DNS 접속 시 503
영향: public endpoint에서 web page 접근 불가
증거: ALB active / target group unhealthy / health check path /health, app은 / 만 응답
원인 후보: health check path mismatch
조치: health check path 를 / 로 변경
재확인: target healthy, curl 200
예방: app health endpoint와 target group 설정을 runbook에 기록
```

### CloudWatch / CloudTrail (오늘 수준 = 위치 확인)
| 도구 | 오늘 | 용도 |
|---|---|---|
| CloudWatch Metrics | ALB/EC2 metric 위치 | 상태·성능 지표 |
| CloudWatch Logs | preview | app log 수집 |
| CloudTrail | Event history 검색 | **SG/ALB/EC2 API 변경 누가 했나** |

> SG rule 변경자는 CloudWatch Logs가 아니라 **CloudTrail** `AuthorizeSecurityGroupIngress`/`RevokeSecurityGroupIngress`에서 찾는다.

### 진단 3종 세트 (Day2 누적)
| 도구 | 보는 것 | 판단 |
|---|---|---|
| `tcpdump -i any port 80` | 패킷이 들어오나 | 안 들어옴=앞단(SG) |
| `curl localhost` vs `curl publicIP` | SG가 어디서 거르나 | localhost만 됨=SG/ENI |
| `netstat`/`ss` 80 LISTEN | app이 사나 | 없음=app(refused) |

### Evidence Note (배움일기용)
```markdown
# W5D2S7 operations observation
- User symptom:
- ALB status:
- Listener:
- Target health:
- EC2 status checks:
- SG checked:
- System log checked:
- Recheck result:
```

### 한 줄 요약
운영 관찰은 **한 화면의 초록불이 아니라 요청 경로 전체의 evidence를 연결**하는 일이다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| ALB active인데 503 | active ≠ 정상. ③ target health reason(path/port mismatch) |
| 갑자기 접속 안 됨 | ⑦ CloudTrail에서 SG 변경 event(누가·언제) |
| CloudWatch에 데이터 없음 | 지표 지연 가능 → 실패로 단정 말고 **resource 상태·event 먼저** |
| user data 실패를 app 문제로 오진 | ⑤ system log(console output)에서 cloud-init 확인 |
