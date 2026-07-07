# 2교시: EC2 Console 실습

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| EC2 launch는 클릭 한 번인가? | ❌ **여러 운영 선택의 묶음**: AMI·type·key pair·network(subnet/public IP)·SG·storage·tag. 마지막 버튼 전 **summary를 반드시 읽음**(실무 배포 전 review와 같음) |
| key pair는 무엇인가? | Linux instance 접속용 **public/private key credential**. private key로 SSH 접속 증명. **다시 다운로드 불가** → 분실 시 접속 어려움, 공개 repo 유출 시 사고 |
| private key는 어떻게 기록? | 파일 **위치만** 배움일기에 기록, **내용은 절대 붙여넣지 않음**. OS별 파일 권한 다름(Linux/mac은 `chmod 400`) |
| 접속 방식 3가지 차이는? | **Instance Connect**(browser, OS/Region/subnet/public IP/SG 조건) / **SSH client**(현업 유사, key 권한·username·local net) / **Session Manager**(운영친화, SSM agent+IAM role+route 필요) |
| 접속 실패, 어디부터? | permission denied=key/username, SSH **timeout**=SG inbound 22 source, 외부접속 불가=**public IP 없음**, Connect 버튼 실패=지원 OS/network |
| SG 최소 rule은? | SSH TCP **22 = 내 IP**(전체공개 오래 유지 ❌), HTTP TCP **80 = 수업 중 임시 `0.0.0.0/0` 가능, 종료 전 삭제**. `0.0.0.0/0`=모든 IPv4 |
| instance type 선택 기준? | 성능이자 **비용 선택**. 수업은 **비용 통제 우선**(작은 type). 큰 type은 빠르지만 잘못된 기본값을 심음 |
| running인데 접속 안 되면 app 문제? | ❌ 먼저 network. **public IP → SG 22 → key/username** 순. status check(⑤)도 확인 |

## notes

### EC2 launch 순서 (Console에서 위→아래로 읽기)
| 단계 | 확인 |
|---|---|
| Name and tags | `Course=paperclip`, `Week=5`, `Day=2`, `Owner=<id>` |
| AMI | 수업 OS·명령과 맞는지 |
| Instance type | 비용 통제 가능한 **작은 type**(예 t3.micro) |
| Key pair | 새로 만들면 안전 보관, 재사용이면 소유 확인 |
| Network settings | VPC, **public subnet**, **auto-assign public IP** |
| Security Group | SSH/HTTP inbound **최소** 허용 |
| Storage | root volume size + **delete on termination** |
| Advanced details | user data 사용 여부 |

```text
AMI → Instance type → Key pair → Subnet/Public IP → Security Group
   → Launch → Connect / HTTP check → Evidence note
```

### 접속 방식 비교
| 방식 | 장점 | 확인할 것 |
|---|---|---|
| EC2 Instance Connect | browser에서 빠름 | OS/Region/subnet/public IP/SG 조건 |
| SSH client (Xshell) | 현업과 유사 | private key 권한, username, local net |
| Session Manager | 운영 친화 | SSM agent, IAM role, VPC endpoint/internet route |

> Day2는 Instance Connect **또는** SSH 중 되는 방식으로. **둘 다 실패하면 먼저 SG와 public IP**를 본다.

> 🖥️ **Xshell 접속 설정 (수업 환경)** — Host=`$PUBIP`, Port=`22`, **User Name = `ec2-user` 고정**(Amazon Linux AMI 기준), 인증은 Public Key로 **`.pem` key 파일 지정**(비밀번호 아님). AMI가 Ubuntu면 `ubuntu`지만 이 수업은 Amazon Linux라 **`ec2-user`**.

### Security Group 최소 예시
| 목적 | Protocol | Port | Source |
|---|---|---|---|
| SSH | TCP | 22 | **내 IP** 또는 교육장 CIDR |
| HTTP | TCP | 80 | 수업 중 임시 `0.0.0.0/0` 가능, **종료 전 삭제** |

### 접속 실패 판단표
| 실패 지점 | 증상 | 확인 |
|---|---|---|
| key 문제 | permission denied | username / key pair |
| SG 22 닫힘 | SSH timeout | inbound 22 source |
| public IP 없음 | 외부 접속 불가 | instance networking |
| Instance Connect 불가 | Connect 버튼 실패 | 지원 OS, network |

### 생성 전 멈춤 지점 (제일 중요)
launch 마지막 버튼 전 **summary를 읽는다**. AMI·type·subnet·public IP·SG·storage·tag 중 **하나라도 설명 못 하면 아직 launch 준비 안 된 것**.

### Key pair 운영 주의
private key는 **재다운로드 불가**. 분실=접속 어려움, 공개 repo 유출=credential 사고. 위치만 기록, 내용은 절대 남기지 않음.

### Evidence Note (배움일기용)
```markdown
# W5D2S2 EC2 launch
- Instance name:
- AMI:
- Instance type:
- Key pair:
- VPC/subnet:
- Public IP auto-assign:
- Security Group inbound:
- Tags:
- Storage:
```

### 한 줄 요약
EC2 launch는 **AMI/type/key/network/SG/storage/tag를 한 번에 결정하는 운영 선택**이다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |