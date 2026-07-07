# 6교시: ALB Console 실습

```bash
# 이 교시 실습 변수 (생성 후 값 채우기)
export REGION=ap-northeast-2
export ALB_DNS=my-alb-xxxx.ap-northeast-2.elb.amazonaws.com   # ALB DNS name
export TG_ARN=arn:aws:elasticloadbalancing:...:targetgroup/...
export PUBIP=x.x.x.x                                           # EC2 public IP (direct 확인용)
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① (선행) `curl -m 5 -i http://$PUBIP/` → **EC2 direct 먼저 정상 확인** | |
| ② (Console) Target group 생성: type=instance, HTTP, **port 80**, EC2와 **같은 VPC**, health check path `/` | |
| ③ (Console) EC2 instance를 target 등록 | |
| ④ (Console) ALB 생성: internet-facing, **2개 AZ public subnet**, SG=HTTP 80 inbound, Listener HTTP 80 → target group | |
| ⑤ `aws elbv2 describe-target-health --region $REGION --target-group-arn $TG_ARN --query "TargetHealthDescriptions[].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}" --output table` → **healthy** 대기 | |
| ⑥ `aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[].{Name:LoadBalancerName,State:State.Code,DNS:DNSName}" --output table` → **active** | |
| ⑦ (성공 확인) `curl -i http://$ALB_DNS/` → EC2 web page 응답 | |
| ⑧ (SG 분리 개념) EC2 SG inbound 80 source를 `0.0.0.0/0` → **ALB SG만** 허용으로 좁히고 ⑦ 재확인 | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| ALB 실습의 성공 기준은? | **ALB active가 아니라 target healthy + ALB DNS HTTP 응답**. ALB만 떠도 target 없으면 traffic 갈 곳 없음 |
| 만드는 순서와 이유는? | **EC2 direct 성공 → target group → ALB → ALB DNS**. EC2가 응답 안 하는데 ALB 붙이면 **장애 범위만 늘어남**. 선행 조건이 direct 정상 |
| target이 unhealthy로 남는 흔한 원인? | ① **target group port ≠ app port** ② **health check path**가 실제 응답 path와 다름 ③ **target group VPC ≠ EC2 VPC** ④ EC2 SG가 health check 트래픽 차단 |
| ALB DNS가 timeout이면? | **ALB SG inbound 80**, subnet(2 AZ), ALB status. user→ALB 구간 문제 |
| ALB DNS가 503이면? | **target group health**. healthy target 없음 → ⑤ reason 확인 |
| EC2 직접은 되는데 ALB만 안 되면? | 그 사이만 봄 → **target group 등록 / listener / ALB SG / ALB→EC2 SG** |
| SG 2개(ALB SG, EC2 SG) 역할은? | **ALB SG**=user→ALB gate(public 80), **EC2 SG**=ALB→EC2 gate. 운영선 EC2 SG는 `0.0.0.0/0` 대신 **ALB SG를 source로** 제한(더 안전) |
| health check reason 읽는 법? | **timeout**=target 도달 실패(SG/subnet/port), **404**=health path 없음(path 수정), **5xx**=app error(app log), **unused**=listener 연결 없음 |

## notes

### 생성 흐름 (순서 중요)
```text
① EC2 direct 성공 확인
② Target group (instance / HTTP / port 80 / EC2와 같은 VPC / health path /)
③ EC2 target 등록
④ ALB (internet-facing / 2 AZ public subnet / SG 80 inbound / Listener 80 → TG)
⑤ Target health = healthy 대기
⑥ ALB DNS로 curl → EC2 web page
```
> ⚠️ **EC2 direct가 먼저 정상**이어야 함. 안 되는 상태로 ALB 붙이면 장애 계층만 늘어남.

### SG 2개 관계 (핵심 구조)
```text
User → [ALB SG :80 public] → ALB → [EC2 SG :80 from ALB SG] → EC2 Web
```
| SG | 역할 | 확인 |
|---|---|---|
| ALB SG | user→ALB gate | inbound 80 from public |
| EC2 SG | ALB→EC2 gate | inbound 80 **source = ALB SG**(운영 권장) |

> 수업 초반엔 EC2 80 public으로 단순화 가능하지만, **최종 정리는 EC2 SG source를 ALB SG로 좁히는 게 안전**(⑧). EC2를 인터넷에 직접 노출 안 함.

### 성공 기준
| 확인 | 성공 |
|---|---|
| Target group | target registered |
| Health | **healthy** |
| ALB | **active** |
| Listener | HTTP 80 → target group forward |
| Browser/curl | ALB DNS에서 EC2 web page 응답 |

### 실패 증상별 첫 확인
| 증상 | 첫 확인 |
|---|---|
| ALB DNS **timeout** | ALB SG inbound, subnet, ALB status |
| **503** Service Unavailable | target group health |
| target **unhealthy** | EC2 SG, health check path, app port |
| EC2 direct는 됨, ALB만 안 됨 | target group/listener/ALB SG |

### target health reason 읽기
| reason | 해석 | 첫 조치 |
|---|---|---|
| timeout | target 도달 실패 | SG, subnet, port |
| 404 | health path 없음 | path 수정 |
| 5xx | app error | app log |
| unused | ALB/listener 연결 없음 | listener/rule |

### Evidence Note (배움일기용)
```markdown
# W5D2S6 ALB console
- Target group name:
- Health check path:
- Registered target:
- Target health:
- ALB name/DNS:
- Listener:
- curl result:
```

### 한 줄 요약
ALB 실습 성공은 **ALB active가 아니라 target healthy + ALB DNS HTTP 응답**이다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| target이 계속 **unhealthy** | ① TG port vs app port ② health check **path** ③ **TG VPC = EC2 VPC** ④ EC2 SG가 health check 허용하는지 |
| ALB DNS **503** | healthy target 0개 → ⑤ target health reason. healthy 될 때까지 **대기·관찰** 필요 |
| ALB DNS **timeout** | user→ALB 구간 → **ALB SG inbound 80**, ALB가 internet-facing·2 AZ인지 |
| EC2 direct OK, ALB만 실패 | 그 사이 → target 등록됨? listener 80 forward? ALB→EC2 SG 열림? |
| ⑧에서 EC2 SG 좁혔더니 접속 실패 | EC2 SG inbound 80 **source가 ALB SG ID**인지(내 IP/CIDR 아님) |
| 실습 끝 비용 | **ALB 자체 삭제** + target group + (필요시 EC2 terminate). ALB는 존재만으로 과금 |
