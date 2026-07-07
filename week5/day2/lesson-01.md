# 1교시: Day1 요약 + AWS 네트워크 실습 지도

```bash
# 이 교시 실습 변수 (본인 값으로 교체)
export REGION=ap-northeast-2                  # 서울, 절대 바꾸지 말 것
export VPC=vpc-xxxxxxxx                        # 관찰할 VPC ID (③에서 확인 후 채우기)
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① `aws sts get-caller-identity --query "{Account:Account,Arn:Arn}"` | |
| ② `aws configure get region` | |
| ③ `aws ec2 describe-vpcs --region $REGION --query "Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,Default:IsDefault}" --output table` | |
| ④ `aws ec2 describe-subnets --region $REGION --filters Name=vpc-id,Values=$VPC --query "Subnets[].{Subnet:SubnetId,AZ:AvailabilityZone,Cidr:CidrBlock,AutoPubIP:MapPublicIpOnLaunch}" --output table` | |
| ⑤ `aws ec2 describe-route-tables --region $REGION --filters Name=vpc-id,Values=$VPC --query "RouteTables[].Routes[?DestinationCidrBlock=='0.0.0.0/0']" --output table` | |
| ⑥ `aws ec2 describe-internet-gateways --region $REGION --filters Name=attachment.vpc-id,Values=$VPC --query "InternetGateways[].{Igw:InternetGatewayId,State:Attachments[0].State}" --output table` | |
| ⑦ `aws ec2 describe-security-groups --region $REGION --filters Name=vpc-id,Values=$VPC --query "SecurityGroups[].{Id:GroupId,Name:GroupName}" --output table` | |
| ⑧ (traffic path 그리기) Browser → EC2 Public IP → SG → app / Browser → ALB DNS → Target Group → SG → app | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| public subnet의 정의는? | subnet **이름**이 아니라, **route table에 `0.0.0.0/0 → internet gateway(IGW)` route가 있는** subnet. 이름에 public이라 적혀도 route 없으면 public 아님 |
| EC2가 외부 접속되려면 필요한 5가지는? | ① VPC(경계) ② public subnet(IGW route) ③ **public IPv4/EIP** ④ route table `0.0.0.0/0→IGW` ⑤ **SG inbound**(22/80). 하나만 빠져도 접속 실패 |
| EC2 running인데 접속 안 됨, 어디부터? | app보다 먼저 network. **public IP → route(IGW) → SG inbound** 순. app은 그 다음(connection refused일 때 process 확인) |
| 장애 증상으로 위치를 좁히면? | **timeout**=network gate(IP/route/SG), **connection refused**=host 도달·port listen 안 함(process), **403/404**=HTTP 응답·path/permission, **503 from ALB**=healthy target 없음 |
| SG는 어디 단위 gate인가? | **resource 단위**(instance 등) inbound/outbound 허용점. stateful. app 문제와 network 차단을 섞지 말 것 |
| Day1에서 오늘로 가져오는 값? | Account ID(소유·비용 경계), **Region `ap-northeast-2`**(조회·생성 위치), Budget(비용 감시), IAM identity(누가 만들었나), Tag(cleanup·추적) |
| 오늘 실습의 비용 급소는? | **ALB**(있는 것만으로 과금) + EC2 + public IPv4. **종료 전 삭제**가 핵심. EC2만 지우고 ALB 남기는 실수 잦음 |

## notes

### 오늘 목표 = resource 생성이 아니라 traffic path 먼저 그리기
EC2/ALB 실습 최대 난관은 "**어디가 막혔는지**" 모르는 것. 경로를 먼저 그려두면 증상으로 구간을 좁힐 수 있다.
```text
[1단계 ALB 없이]  Browser/curl → EC2 Public IP → SG(inbound) → EC2 web server(app)
[2단계 ALB 추가]  Browser/curl → ALB DNS → Target Group → SG → EC2 web server(app)
```

### public subnet 조건 (외부 접속 5요소)
| 항목 | 외부 접속에 필요한 이유 |
|---|---|
| VPC | network 경계 |
| Subnet | EC2가 놓이는 AZ/network |
| **Route table** | internet-bound traffic의 다음 hop(`0.0.0.0/0→IGW`) |
| **Internet Gateway** | VPC ↔ internet 연결 |
| **Public IPv4/EIP** | internet에서 EC2를 직접 찾는 주소 |
| **Security Group** | 들어올 protocol/port/source 허용 |

> ⚠️ 이름이 `public-subnet`이어도 **route table에 IGW route가 없으면** public처럼 동작하지 않는다. public 여부는 **이름이 아니라 route**로 판단.

### 장애 증상 → 첫 확인 (구간 좁히기)
| 증상 | 의미 | 첫 확인 |
|---|---|---|
| timeout | 경로 중간에서 응답 없음 | public IP · route · SG |
| connection refused | host 도달, port listen 안 함 | web server process |
| 403/404 | HTTP 응답, path/permission 문제 | index/path |
| 503 from ALB | healthy target 없음 | target group health |

### 오늘의 안전 규칙 (비용·보안)
- root user로 실습하지 않는다 / **Region 바꾸지 않는다**
- SSH **22는 내 IP로 제한**, HTTP **80은 목적에 맞게 열고 종료 전 닫기/삭제**
- **ALB는 존재만으로 과금** → 종료 전 삭제
- 모든 resource에 **tag**(Owner/Purpose/Week)
- 계정 불안정하면 무리해서 유료 resource 만들지 말고 **Console preview·시뮬레이션 evidence**만 남겨도 됨

### 삭제 순서 (비용 잔여 방지)
ALB/Listener → Target Group → EC2(terminate) → 안 쓰는 EIP release → SG. **EC2만 지우고 ALB 남기는 실수**가 가장 흔함 → ALB·TG·SG·EC2를 각각 검색해 확인.

### Evidence Note (배움일기용)
```markdown
# W5D2S1 network lab map
- Account ID:
- Region:
- VPC ID:
- public subnet ID:
- route table: 0.0.0.0/0 -> igw?
- 오늘 만들 resource:
- cleanup 예정 시각:
```

### 한 줄 요약
EC2 접속 장애는 app보다 먼저 **Region → subnet route(IGW) → public IP → Security Group**을 본다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| resource가 조회 안 됨 | 대개 **Region** 문제. `--region $REGION`과 콘솔 우측 상단 Region 일치 확인 |
| ⑤ route 결과가 비어 있음 | 그 route table에 `0.0.0.0/0→IGW`가 없음 → 해당 subnet은 public 아님 |
| ④에서 AutoPubIP=False | launch 시 public IP 자동 할당 안 됨 → EC2 생성 때 public IP 명시 or EIP 필요 |
