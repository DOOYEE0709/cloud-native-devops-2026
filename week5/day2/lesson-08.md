# 8교시: 구름 EXP 배움일기

```bash
# 이 교시 실습 변수
export REGION=ap-northeast-2
export INSTANCE=i-xxxxxxxxxxxx
export SG=sg-xxxxxxxxxxxx
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① (배움일기) 아래 템플릿의 traffic path·성공 evidence·장애 분석·cleanup 먼저 채우기 | |
| ② (삭제 전 목록) `aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[].LoadBalancerName" --output table` | |
| ③ (ALB 삭제) Console에서 ALB → listener/LB 삭제 (또는 `aws elbv2 delete-load-balancer --load-balancer-arn <ALB_ARN>`) | |
| ④ (target group 삭제) unused 확인 후 `aws elbv2 delete-target-group --region $REGION --target-group-arn <TG_ARN>` | |
| ⑤ (EC2 정리) `aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE` (또는 stop) | |
| ⑥ (EBS 확인) `aws ec2 describe-volumes --region $REGION --filters Name=status,Values=available --query "Volumes[].VolumeId" --output table` → detached volume 잔여 확인 | |
| ⑦ (SG 삭제) 실습 SG(default 아님) 삭제 — attached 해제 후 | |
| ⑧ (삭제 후 검색) EC2 / Load Balancers / Target Groups / Volumes 각각 **검색해서 없음 확인** | |
| ⑨ (비용 확인) Billing/Cost Explorer에서 EC2·ELB 항목 확인(지연 가능) | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| W5D2의 진짜 끝은? | **ALB 접속 성공이 아니라 evidence 정리 + cleanup audit**. 종료 버튼이 끝이 아님 |
| cleanup이 왜 별도 과제가 아닌가? | ALB·EBS·Elastic IP·log group·snapshot·NAT GW처럼 **눈에 안 띄는 resource가 비용**을 만듦 → cleanup은 실습의 **마지막 단계** |
| EC2만 terminate하면 끝? | ❌ **ALB·target group·detached EBS·EIP·SG**가 남을 수 있음. EC2 하나로 안 끝남 |
| 삭제 순서는? | **ALB(listener/LB) → target group → EC2 → EBS → SG → key pair → 비용 확인**. 의존 관계 때문에 위에서부터 |
| ALB를 "잠깐 남긴다"의 위험? | **존재만으로 과금**. 남기려면 **사유 + 삭제 예정 시각** 기록 |
| stop vs terminate? | stop=compute만 멈춤(**EBS 비용 남음**), terminate=영구 삭제. stop해도 비용 0 아님 |
| 좋은 cleanup 기록이란? | "삭제함"❌ → **resource 이름·상태·삭제 시각·유지 사유**. 걱정되면 Cost Explorer에서 service별 재확인 |
| Day3와 어떻게 연결? | D3는 EC2 직접 설치 대신 **container image를 service가 실행** → **ALB·target group·health check·port 개념 그대로 재등장**. port·health check를 정리해두면 D3가 쉬움 |

## notes

### 배움일기 템플릿
```markdown
# W5D2 AWS network and EC2/ALB
## 1. 오늘 만든 resource
- Region / EC2 / Security Group / Target Group / ALB
## 2. Traffic path
Browser/curl -> ALB SG -> ALB -> Target Group -> EC2 SG -> EC2 web server
## 3. 성공 evidence
- EC2 public IP curl / ALB DNS curl / Target health
## 4. 장애 분석
- 주입한 실패 / 실패 증상 / 확인한 위치 / 복구 방법 / recheck 결과
## 5. Cleanup
- EC2 / ALB / Target Group / Security Group / EBS / Key Pair
## 6. Day3 질문
```

### Cleanup 순서 (의존 관계 순)
| 순서 | 대상 | 확인 |
|---|---|---|
| 1 | ALB listener/load balancer | deleted/deleting |
| 2 | Target group | unused 후 delete |
| 3 | EC2 instance | stop/terminate 결정 |
| 4 | EBS volume | delete on termination / **detached volume** |
| 5 | Security Group | default 아닌 실습 SG |
| 6 | Key Pair | 필요 없으면 삭제, local .pem도 관리 |
| 7 | Cost/Billing | 비용 항목 확인 |

> ⚠️ **삭제는 EC2 하나로 안 끝난다.** ALB·target group도 별도 resource. 삭제 후 **검색 결과까지** 확인.

### 삭제 전 확인할 의존 관계
| resource | 의존 | 순서 힌트 |
|---|---|---|
| ALB | listener, target group | ALB 삭제 후 TG |
| Target Group | registered target | ALB 연결 해제 후 |
| EC2 | EBS, SG, key pair | terminate/stop |
| EBS | EC2 root/data volume | detached 확인 |
| SG | EC2/ALB attached 여부 | 연결 해제 후 |

### 유지하는 경우 (Day3에 EC2 이어쓰기)
남긴다면 **유지 대상 / 사유 / 예상 비용 / 삭제 예정 시각**을 기록. 특히 **ALB "잠깐 남김" = 비용**.

### Day2 → Day3 연결
D3: container image를 service가 실행 → 오늘의 **ALB / target group / health check / port**가 그대로 재등장. Day2 배움일기에 **port·health check** 정리해두면 D3가 훨씬 쉬움.

### Evidence Note (배움일기용)
```markdown
# W5D2S8 cleanup journal
- Region:
- Traffic path evidence:
- 장애 주입/복구 요약:
- 삭제한 resource:
- 유지한 resource와 사유:
- Day3 연결 질문:
```

### 한 줄 요약
W5D2의 끝은 **ALB 접속 성공이 아니라 evidence 정리와 cleanup audit**이다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| 실습 끝났는데 비용 계속 | **ALB 자체 삭제** 안 함 / detached **EBS** / **EIP** 잔여 → 각각 검색 |
| target group 삭제 안 됨 | ALB **연결(listener) 먼저 해제** 후 삭제 |
| SG 삭제 안 됨 | EC2/ALB에 **attached** 상태 → 연결 해제 후 |
| EC2 stop했는데 비용 남음 | stop은 compute만 멈춤, **EBS 비용 지속** → 필요없으면 terminate |
| 삭제했는데 콘솔에 보임 | 전파 지연 → ⑧ 검색으로 재확인. deleting→deleted 확인 |
