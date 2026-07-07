# 5교시: Load Balancing 개념

```bash
# 이 교시 실습 변수 (6교시에서 ALB 만들면 채우기)
export REGION=ap-northeast-2
export TG_ARN=arn:aws:elasticloadbalancing:...:targetgroup/...   # target group ARN
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① (개념 그리기) ALB → Listener :80 → Target Group → Health Check → EC2 target 흐름을 그림으로 그리고 각 역할 한 줄씩 | |
| ② `aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[].{Name:LoadBalancerName,Scheme:Scheme,DNS:DNSName,State:State.Code}" --output table` | |
| ③ `aws elbv2 describe-listeners --region $REGION --load-balancer-arn <ALB_ARN> --query "Listeners[].{Port:Port,Proto:Protocol}" --output table` | |
| ④ `aws elbv2 describe-target-groups --region $REGION --query "TargetGroups[].{Name:TargetGroupName,Port:Port,Proto:Protocol,HCPath:HealthCheckPath}" --output table` | |
| ⑤ `aws elbv2 describe-target-health --region $REGION --target-group-arn $TG_ARN --query "TargetHealthDescriptions[].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}" --output table` | |
| ⑥ (비교) ALB DNS로 접속 vs EC2 public IP로 접속 — endpoint가 분리됨을 확인 | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| ALB가 해결하는 문제는? | EC2 public IP 직접 접속은 instance 교체·장애·확장 때 **사용자가 바로 영향**받음. ALB는 **사용자가 보는 endpoint(ALB DNS)와 backend target을 분리** → target 바꿔도 사용자는 ALB DNS 기준. 이 분리가 load balancing의 핵심 |
| 4대 구성요소 역할은? | **ALB**=진입점(internet-facing/internal) / **Listener**=받을 protocol·port(80/443) / **Target Group**=보낼 대상 묶음(protocol·port) / **Health Check**=healthy target에만 보내는 판단 gate |
| Health check는 그냥 ping인가? | ❌ **배포 품질 gate**. "이 target에 사용자 traffic 보내도 되나" 판단. path 틀리거나 app port 다르면 **unhealthy** → ALB가 traffic 안 보냄. K8s **readinessProbe와 같은 목적** |
| ALB DNS 있으면 끝인가? | ❌ **target health**부터 확인. healthy target 없으면 ALB는 떠 있어도 **503**. "DNS 있음 ≠ 서비스 정상" |
| 503 from ALB의 첫 확인은? | **target health reason**. health check path/port가 app과 맞는지 → target group port vs app listen port |
| public ALB + private target 구조? | 운영선 ALB는 **public subnet**, app target은 **private subnet**. SG로 **ALB→target** traffic 허용. 사용자는 private에 직접 못 감 |
| K8s와 매핑하면? | Service↔target group(일부), **Ingress/Gateway↔listener/rule**, **readinessProbe↔health check**, EndpointSlice↔registered targets. **단 같은 계층 아님**(비교는 이해용) |
| ALB 비용 주의? | **target 없어도·traffic 없어도 생성돼 있으면 과금**. target group만 비워도 ALB 남으면 계속. **Day2 종료 전 삭제 확인 필수**(초보 비용 사고 단골) |

## notes

### ALB 요청 흐름
```text
Browser → ALB DNS → Listener(:80) → Target Group → (Health Check) → EC2 target A/B
```
| 구성요소 | 한 줄 | 확인 질문 |
|---|---|---|
| ALB | HTTP/HTTPS 진입점 | internet-facing인가 internal인가 |
| Listener | 받을 port/protocol | 어떤 port로 받는가(80/443) |
| Rule | 요청 → 대상 라우팅 | 어떤 요청을 어디로 |
| Target Group | 보낼 대상+port 묶음 | 어떤 대상·port로 보내는가 |
| Health Check | healthy만 traffic gate | 어떤 path/status를 정상으로 |
| SG | user→ALB, ALB→target 허용 | 두 구간 다 열렸나 |

### ALB의 핵심 = endpoint와 backend 분리
EC2 public IP 직접 접속 → instance 교체·장애·확장 시 사용자 직격. **ALB는 사용자 endpoint(ALB DNS)와 target을 분리** → target 추가/교체해도 사용자는 ALB DNS로 동일하게 접근. **이 분리가 load balancing의 본질.**

### Health check = 배포 품질 gate (단순 ping 아님)
"이 target에 사용자 traffic 보내도 되나"를 주기적으로 판단. **path 틀림·app port 불일치 → unhealthy → traffic 차단.** K8s readinessProbe를 배운 이유가 여기서 재등장.
> ⭐ **ALB DNS 있음 ≠ 서비스 정상.** healthy target 없으면 **503**. 503 나면 **target health reason부터**.

### public ALB + private target (운영 구조)
| 구성 | 의미 |
|---|---|
| Internet-facing ALB | 인터넷에서 접근 (public subnet) |
| Internal ALB | VPC 내부만 |
| Private subnet | app/DB target 배치 |
| SG | ALB→target traffic 허용 |

### K8s ↔ ALB 매핑 (계층은 다름, 이해용)
| Kubernetes | AWS ALB |
|---|---|
| Service | target group과 일부 유사 |
| Ingress/Gateway | listener/rule |
| readinessProbe | health check |
| EndpointSlice | registered targets |
| kube-proxy/routing | ALB data plane(계층 다름) |

### ⚠️ ALB 비용 경계 (제일 자주 사고나는 곳)
ALB는 **target 없어도·traffic 없어도 존재만으로 과금**. target group만 비운다고 안 끝남 → **ALB 자체를 삭제**해야 함. **Day2 종료 전 삭제 확인 필수.**

### Evidence Note (배움일기용)
```markdown
# W5D2S5 ALB concept
- ALB type:
- Listener:
- Target group protocol/port:
- Health check path:
- Public endpoint:
- 비용 cleanup 대상:
```

### 한 줄 요약
ALB는 **public entry point**이고, **target group과 health check**가 실제 traffic 대상을 결정한다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| ALB DNS 접속했는데 **503** | healthy target 없음 → ⑤ target health **reason**, health check path/port가 app과 맞는지 |
| target이 계속 **unhealthy** | health check **path**(실제 응답 path와 다름), **port**(app listen port와 다름), SG(ALB→target) 확인 |
| ALB는 만들었는데 접속 자체 안 됨 | listener port(80), user→ALB SG inbound, ALB가 internet-facing인지 |
| 실습 끝났는데 비용 계속 | **ALB 자체 삭제** 안 함(target group만 비운 것). ELB 콘솔에서 LB 삭제 확인 |
