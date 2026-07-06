# 6교시: EC2 첫 관찰

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| EC2란? | AWS의 virtual server. Docker/Pod보다 아래 계층 compute. EC2 위에 Docker 설치·K8s node로도 씀 |
| AMI가 뭔가? | instance의 시작 OS image. 문서 명령과 OS가 다르면 실습 실패 |
| stop vs terminate? | stop=compute 비용 멈추지만 **EBS 등 storage 비용 남을 수 있음**, terminate=**영구 삭제(복구 불가)** |
| stop하면 비용 0인가? | ❌ EBS·Elastic IP·snapshot·LB 등은 비용 지속 가능. cleanup은 "EC2 stop" 하나로 안 끝남 |
| running인데 HTTP 안 되면? | running은 instance 상태지 app 정상 아님 → status check / SG / app process 나눠 확인 |
| user data는? | 최초 부팅 bootstrap script. "손으로 한 설정"과 달리 생성 시점에 묶여 **재현성**↑(완전한 IaC는 아님) |

## notes

### EC2 = 가상 서버(아래 계층 compute)
```text
EC2 instance
 ├ OS         : AMI에서
 ├ vCPU/메모리 : instance type에서
 ├ 디스크      : EBS volume
 ├ 네트워크    : ENI / private IP / (선택)public IP
 └ 방화벽      : Security Group
```
Docker container·K8s Pod보다 아래 계층. EC2 위에 Docker 설치하거나 K8s node로 쓴다.

### 생성 전 읽을 값 (Day2 실습 전 관찰)
| 항목 | 의미 | 위험 |
|---|---|---|
| AMI | 어떤 OS image로 시작 | 문서와 OS 다르면 실패 |
| Instance type | CPU/메모리/네트워크 크기 | 비용 증가 |
| Key pair | SSH 접속 key | 분실/노출 |
| Network | VPC/subnet/public IP | 접속 불가 또는 public 노출 |
| Security Group | 허용 traffic | 22/80 과다 노출 |
| Storage | root EBS size / delete on termination | 잔여 비용 또는 데이터 삭제 |
| Tag | owner/purpose 추적 | cleanup 누락 |

### Stop vs Terminate (비용/복구)
| 상태 | 의미 | 비용/복구 |
|---|---|---|
| running | 실행 중 | compute 비용 발생 |
| stopped | 정지 | compute 멈춤, **EBS 비용 가능** |
| terminated | 삭제 | **복구 불가, 연결 불가** |

> ⚠️ **stop = 안전한 삭제 아님.** compute만 멈추고 EBS·Elastic IP·snapshot·LB 비용은 남을 수 있음 → cleanup checklist는 "EC2 stop" 하나로 끝내면 안 됨.

### User data (부팅 시 재현되는 설정)
최초 부팅 때 실행되는 bootstrap script. "서버 들어가 손으로 한 설정"은 다음에 순서가 누락될 수 있지만, user data는 절차를 **생성 시점에 묶어 재현성**을 높인다(완전한 IaC는 아님).
```bash
#!/bin/bash
echo "hello from paperclip w5" > /var/www/html/index.html
```
(AMI/웹서버 설치 상태에 따라 그대로 안 될 수 있음 — Day2에서 AMI에 맞는 전체 script)

### 생성 전 의사결정 (자주 하는 실수 → 안전)
| 선택 | 실수 | 안전 |
|---|---|---|
| AMI | 문서와 다른 OS | 수업 명령과 맞는 AMI |
| Instance type | 큰 type | 실습용 작은 type |
| Key pair | 저장 위치 모름 | 위치·권한 기록 |
| Public IP | 꺼두고 접속 기대 | 필요 시 enable |
| Storage | terminate 후 data 보존 오해 | EBS delete 옵션 확인 |
| Tag | 이름만 | Owner/Purpose/Week |

### 인스턴스 타입 네이밍 (질문에서 나온 것)
맨 앞 글자 = **용도(family)**.
| 글자 | 계열 | 용도 |
|---|---|---|
| **t** | 범용(버스트) | 저렴, 평소 낮다 가끔 튐(크레딧). 실습·소규모 |
| **m** | **범용** | CPU:메모리 균형. 일반 서버 기본값 |
| **c** | 컴퓨트 최적화 | CPU 강함(연산·배치) |
| **r** | **메모리 최적화** | RAM 많음(캐시·인메모리 DB) |
| **x, z** | 초고메모리 | 대형 DB |
| **g** | **GPU** | 그래픽/ML 추론 |
| **p** | GPU(고성능) | ML 학습 |
| **i, d** | 스토리지 최적화 | 로컬 NVMe/HDD 대용량·고IOPS |

**이름 읽는 법** — `m6i.large`:
```text
m      6        i          .large
family 세대     칩변형       크기
(용도) (숫자↑최신) i=Intel/a=AMD/g=Graviton(ARM)   nano<micro<small<medium<large<xlarge<2xlarge...
```
- 예: `t3.micro`(범용버스트·실습단골), `m6i.large`(범용6세대Intel), `r6g.xlarge`(메모리·Graviton), `g5.xlarge`(GPU).
- 뒤에 `g`(예: `m7g`)=**Graviton(ARM)** → 같은 성능에 더 싸고 전력효율↑(ARM 이미지 필요).
- 크기 한 단계 = vCPU·메모리 약 2배(가격도 비례). → 6교시 "필요 이상 큰 type 금지"와 연결.
> 첫 글자=용도, 숫자=세대, 뒤 글자=칩, `.크기`=스펙. **용도에 맞는 최소 크기**가 정답.

### Elastic IP(EIP) 과금 — "안 쓰면 더 문다" (질문에서 나온 것)
EIP = 계정에 고정 할당받는 **정적 공인 IPv4**. stop/start 해도 IP가 안 바뀜(일반 public IP는 바뀜).
| 상황 | 과금 |
|---|---|
| running 인스턴스에 **연결해서 사용** | (예전) 무료 → **2024.2~ 시간당 과금** |
| 할당만 하고 **연결 안 함(놀림)** | **시간당 추가 과금**(희소 자원 낭비 방지) |
| 연결했는데 인스턴스 stopped | 과금(안 쓰는 셈) |

- ⭐ 2024년부터 IPv4 부족으로 **"쓰는 공인 IPv4"도 시간당 과금**(EIP·일반 public IP 모두, 약 $0.005/h ≈ 월 3~4천원). 이제 기준은 "고정이냐"보다 **"공인 IPv4를 쓰느냐"**.
- 특히 **안 붙은 EIP는 여전히 추가 과금** → 실습 후 **안 쓰는 EIP는 release(반납)** 필수.
> "고정이라 더 받는다"보다 **"공인 IPv4 자체가 유료 + 놀리는 EIP는 더 문다"**가 정확. (2교시 "무심코 만든 리소스 비용"과 연결)

### 한 줄 요약
EC2는 만들기 전에 **AMI·type·network·SG·storage·tag·cleanup 기준**을 먼저 읽는다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| instance는 running인데 HTTP 안 됨 | running=instance 상태지 app 정상 아님. status check → SG inbound → app process(그 port listen?) 순으로 분리 |
| stop했는데 비용이 계속 나감 | EBS volume·Elastic IP·snapshot 등 잔여 비용. terminate 또는 개별 리소스 삭제 필요 |
