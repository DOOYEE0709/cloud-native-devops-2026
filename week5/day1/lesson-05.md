# 5교시: VPC와 Security Group 기본

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| VPC란? | AWS 안의 격리된 가상 network 경계(예: `10.0.0.0/16`). EC2/ALB/RDS가 이 안에 놓임 |
| public subnet의 조건은? | route table의 `0.0.0.0/0`이 **IGW**로 향하고 + instance에 **public IP** + SG 허용까지 맞아야 |
| Security Group은 stateful? | ✅ stateful — 허용한 inbound의 응답은 outbound rule 없이도 돌아감. (NACL은 stateless) |
| EC2 접속이 안 될 때 볼 순서는? | timeout/refused 구분 → public IP → route table IGW → SG inbound source → app이 그 port에서 listen하는지 |
| SG만 열면 외부 접속되나? | ❌ public IP·route(IGW)·SG inbound가 **함께** 맞아야 됨 |
| Service와 SG를 같게 보면? | 오해. Service=cluster 안 endpoint 추상화, SG=AWS resource에 도달 가능한 traffic 허용/차단(계층 다름) |

## notes

### VPC 구성요소
```text
Internet → Internet Gateway → Route Table(0.0.0.0/0 → IGW)
        → VPC(10.0.0.0/16) → Public Subnet(10.0.1.0/24) → EC2 + Security Group
```
| 구성요소 | 설명 | 첫 확인 |
|---|---|---|
| VPC | AWS 안 격리된 network | VPC ID, CIDR |
| Subnet | VPC CIDR 일부를 **AZ에 배치** | subnet ID, AZ, route table |
| Route Table | traffic의 다음 hop 결정 | `0.0.0.0/0` target |
| Internet Gateway | VPC ↔ internet 연결 | attached VPC |
| Security Group | resource 단위 inbound/outbound 허용 | protocol, port, source |

### Security Group = stateful 방화벽
허용한 inbound 요청의 **응답은 자동으로 돌아감**(outbound를 세밀히 안 열어도 됨). NACL과 헷갈리지 말 것.
| 질문 | SG에서 볼 것 |
|---|---|
| SSH 안 됨 | inbound TCP **22** source |
| HTTP 안 됨 | inbound TCP **80** source |
| app port 다름 | app listen port와 SG port 일치 |
| 아무나 열림 | source `0.0.0.0/0` 또는 `::/0` ⚠️ |
| DB가 public | inbound **3306/5432** source |

### SG vs Network ACL (preview)
| 구분 | Security Group | Network ACL |
|---|---|---|
| 적용 대상 | ENI/resource | **subnet** |
| 상태 | **stateful** | **stateless** |
| 수업 초점 | EC2/ALB 접근 허용 | preview만(현업 장애 시 확인) |

### Kubernetes와 비교
| Kubernetes | AWS |
|---|---|
| Pod IP | EC2 private IP 또는 task ENI |
| Service | target group / service discovery와 일부 비교 |
| Ingress/Gateway | ALB listener/rule |
| NetworkPolicy | SG/NACL과 목적 비슷하나 계층·적용 대상 다름 |
| `kubectl describe svc` | Console에서 ALB/target group/SG/subnet 확인 |

> Service ≠ SG. Service는 cluster 안 endpoint 추상화, SG는 AWS resource에 **도달 가능한 traffic**을 허용/차단.

### public subnet 판정 5단계 (하나라도 빠지면 접속 실패)
```text
① EC2가 어느 subnet에 있나
② 그 subnet의 route table 열기
③ 0.0.0.0/0 target이 Internet Gateway인가
④ instance에 public IPv4가 있나
⑤ SG가 필요한 inbound port를 허용하나
```

### EC2 접속 장애 판단 질문
```text
□ timeout인가 / connection refused인가 / HTTP error인가?
   - timeout    → 대개 SG/route/보안 경로(패킷이 못 닿음)
   - refused    → 닿았는데 그 port에 listen 없음(app 미기동)
   - HTTP error → 닿고 응답도 옴(앱 레벨 문제)
□ public IP 있나 / route에 IGW 있나 / SG inbound source 맞나 / app이 listen하나
```

### 💥 EKS Pod IP 고갈 — CIDR은 처음에 넉넉히 (질문에서 나온 것)
EKS는 기본 **AWS VPC CNI**를 써서 **Pod마다 VPC subnet의 실제 IP**를 받는다(일반 K8s 오버레이와 다름).
```text
일반 K8s   : Pod = 클러스터 내부 가상 IP (VPC IP 안 씀)
EKS(VPC CNI): Pod = VPC subnet의 실제 IP  ← 여기서 고갈
```
- subnet이 작으면(예: `/24` ≈ 251개) Pod 수백 개 뜰 때 **IP 소진 → 새 Pod가 `ContainerCreating`에서 멈춤**.
- 이벤트: `failed to assign an IP address to container` / `no available IP`. 노드는 멀쩡한데 IP만 없음. "네트워크 다운"처럼 보이지만 실제는 **IP 주소 소진**.
- 노드(EC2) 타입마다 붙일 수 있는 IP 수 제한(ENI 개수 × ENI당 IP)도 영향.

**왜 나중에 고치기 어렵나:** subnet CIDR은 만든 뒤 축소·변경이 사실상 불가. 게다가 그 VPC/subnet 위에 EC2·ALB·RDS·ENI가 물려 있어 갈아엎으려면 다 확인·이전해야 함 → **처음에 CIDR을 넉넉히 설계**(되돌리기 비용 큼).

| 완화 | 내용 |
|---|---|
| 넉넉한 CIDR | 처음부터 `/16` VPC + 큰 Pod subnet (가장 중요) |
| Prefix Delegation | 노드에 IP를 `/28` 블록 단위 할당 → 노드당 Pod↑, IP 효율↑ |
| Secondary CIDR | VPC에 추가 CIDR(`100.64.0.0/10` 등) 붙여 Pod 전용 subnet |
| Custom Networking | Pod를 별도 subnet에 배치해 노드 subnet IP 절약 |

> 5교시 "VPC CIDR = 누가 몇 개나 들어올 수 있나"의 실전 사례. 실무성 이슈지만 **CIDR 설계는 처음이 중요**.

### 한 줄 요약
VPC는 AWS resource가 놓이는 **network 경계**, Security Group은 그 resource에 **도달 가능한 traffic**을 정한다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| SG만 80 열었는데 외부 접속 안 됨 | public IP·route table(IGW)·SG inbound를 **함께** 확인. public subnet 5단계 중 빠진 것 찾기 |
| port 닫혔는데 app 문제로 착각 | timeout이면 대개 SG/route(네트워크 경로), refused면 app 미기동 — 증상으로 먼저 갈래 나누기 |
