# 3교시: Region/AZ와 장애 경계

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Region과 AZ 차이는? | Region=독립된 지리적 영역(예: `ap-northeast-2` 서울), AZ=Region 안의 격리된 location(장애 격리 단위) |
| "방금 만든 EC2가 사라졌다"의 진짜 원인은? | 대부분 Region mismatch — 삭제된 게 아니라 조회 Region이 다른 것. Region selector부터 확인 |
| resource를 못 찾을 때 첫 확인은? | 이름이 아니라 **Region** (오른쪽 위 Region selector) |
| 왜 여러 AZ에 분산하나? | 단일 AZ 장애를 견디기 위해(고가용성). multi-AZ 배치 = K8s multi-replica |
| S3 bucket 이름이 중복이라는데? | S3 bucket name은 **전역(global) unique** — Region resource가 아님 |
| EBS attach 실패 첫 확인은? | instance와 volume이 **같은 AZ**인지 (EBS는 AZ 제약) |

## notes

### Region — resource가 존재하는 큰 지리적 경계
독립된 지리적 영역. EC2·VPC·ALB·RDS 등 많은 resource가 **Region 단위**로 생성된다.
```text
ap-northeast-2 = Asia Pacific (Seoul)
```
오늘 기본 Region = `ap-northeast-2` 고정. 다른 Region 쓰면 evidence note에 반드시 기록. 현재 Region은 콘솔 오른쪽 위 Region selector에서 확인.

### Availability Zone(AZ) — Region 안의 장애 격리 단위
Region 내부의 격리된 location. 고가용성 설계는 여러 AZ에 resource를 분산한다.
```text
Region: ap-northeast-2
 ├─ AZ a : subnet-a → EC2
 ├─ AZ b : subnet-b → EC2
 └─ AZ c : subnet-c → RDS standby 등
```

### 서울 리전 AZ + 이름 vs ID 함정 (질문에서 나온 것)
서울(ap-northeast-2)은 현재 **AZ 4개**: `2a` `2b` `2c` `2d`. 처음 2~3개로 시작해 수요 따라 증설(수도권/인천 등에 분산). → "AZ는 리전 안에서 시간이 지나며 늘어난다"의 실제 사례.

⚠️ **AZ 이름 vs AZ ID** — "내 `2a`와 네 `2a`가 같은 물리 건물이 아닐 수 있다."
- AZ **이름**(`ap-northeast-2a`)은 **계정마다 랜덤 매핑**(부하 분산 목적).
- 실제 물리 위치는 **AZ ID**(`apne2-az1`, `apne2-az2`…)로 봐야 함.
```text
aws ec2 describe-availability-zones
 → ZoneName(ap-northeast-2a) + ZoneId(apne2-az1) 둘 다 표시
```
- 언제 중요? 두 계정이 "같은 AZ에 두자"고 이름만 맞추면 다른 건물에 갈 수 있음(크로스 계정 배치, 같은 AZ 내 통신 무료 등).
- 주의: 새로 생긴 `2d`엔 특정 인스턴스 타입/서비스가 없을 수 있어 배치 전 확인.

### 도쿄 vs 서울 — 도쿄를 봐야 할 때 (질문에서 나온 것)
도쿄(ap-northeast-1)는 서울보다 오래되고 큰 리전. 정확한 "몇 배"는 비공개지만 **용량·서비스 폭·성숙도**가 큼.
| | 도쿄(2011~) | 서울(2016~) |
|---|---|---|
| 성숙도 | AWS 최대급 | 상대적으로 젊음 |
| 신기능 | 먼저·더 많이 | 일부 지연 |
| 용량/특수 타입 | 여유 큼 | 가끔 빡빡 |

**도쿄를 보는 경우**: 서울에 없는 신규 서비스/기능, 특정 인스턴스 타입/GPU 부족, `InsufficientInstanceCapacity` 우회, 가끔 가격.
**트레이드오프**: 서울↔도쿄 latency +30~40ms / 데이터 위치(compliance) / 크로스 리전 전송비 / 운영 이원화.
> **수업 기준: 서울 고정.** 국내 교육이라 latency·단순성 유리. 다른 리전 쓸 일 생기면 evidence note에 사유 기록.

### Kubernetes와 연결
| Kubernetes | AWS |
|---|---|
| node | EC2 instance 또는 managed node |
| node zone label | Availability Zone |
| Service endpoint | ALB target 또는 service endpoint |
| PV/PVC zonal disk | EBS volume(AZ 제약) |
| multi-replica | multi-AZ 배치 |

### Region 잘못 보면 생기는 증상 (첫 확인)
| 증상 | 첫 확인 |
|---|---|
| 방금 만든 EC2가 안 보임 | Region selector |
| S3 bucket 이름 중복이라 나옴 | S3 name은 **전역 unique** |
| VPC가 다르게 보임 | Region별 VPC list |
| ALB target 등록 안 됨 | target과 ALB의 VPC/Region 일치 |
| 비용은 있는데 resource 못 찾음 | Cost Explorer의 service/Region filter |

### global vs regional (구분 중요)
- **regional**: EC2, VPC, ALB, RDS, EBS … (Region마다 따로 존재)
- **global**: **S3 bucket 이름**(전역 unique), IAM, CloudFront, Route53 … (Region 무관)
- 그래서 S3 이름 충돌을 "Region 문제"로 오해하면 안 됨.

### Region 선택 의사결정
| 기준 | 질문 |
|---|---|
| latency | 사용자가 어디에 있나 (국내면 서울 우선) |
| service availability | 필요한 service/기능이 그 Region에 있나(새 기능은 일부 Region만) |
| cost | 같은 resource라도 Region별 가격 차이 |
| compliance | 데이터 위치 요구가 있나 |
| failure design | 어느 범위 장애까지 견딜까(multi-AZ vs multi-Region) |

### 콘솔 실험 (초반 필수)
EC2 화면에서 서울 Region → 다른 Region으로 바꾸면 instance list가 달라진다. **삭제된 게 아니라 조회 범위가 바뀐 것.** "방금 만든 게 사라졌다"의 대부분이 Region mismatch.

### 최소 2 AZ 이상 — 고가용성 (질문에서 나온 것)
**단일 AZ = 단일 장애점(SPOF).** 그 AZ가 죽으면 서비스 전체 다운 → **2개 이상 AZ에 분산**.
```text
1 AZ만:   [AZ-a 장애] → 전체 다운 ❌
2 AZ 분산: [AZ-a 장애] → AZ-b가 계속 서빙 ✅
```
AZ는 전원·냉각·네트워크가 독립된 물리 분리 건물이라 장애가 안 번짐. **AWS가 아예 2 AZ를 요구**하기도:
| 서비스 | 요구 |
|---|---|
| ALB | 최소 **2개 AZ subnet** 지정해야 생성 |
| RDS Multi-AZ | standby를 다른 AZ에 두고 자동 failover |
| EKS / ASG | 노드 여러 AZ 분산(ASG 자동 밸런싱) |

- K8s multi-replica를 여러 node에 분산한 것 = AWS **multi-AZ 분산**. "파드 하나 죽어도 OK"처럼 "AZ 하나 죽어도 OK".
- 트레이드오프: 크로스 AZ 전송비(소액, 같은 AZ 내는 무료) — 대량 통신은 같은 AZ, 가용성은 여러 AZ로 균형.

### NAT의 방향 — outbound(나가기)다 (질문에서 나온 것)
집 비유: **NAT = 안방 사람(private 인스턴스)이 밖에 나갈 때 현관 대표주소(NAT 공인 IP)로 나가는 것.** 밖에서는 누가 나갔는지 모르고 대표주소만 봄(내부 IP 숨김) ✅ — 단 이건 **나가는 방향(outbound)**.

⚠️ "현관문 두들김(inbound, 밖→안)"은 NAT이 **아니라 NAT이 막는 것**. 밖에서 들어오는 현관은 **ALB/퍼블릭 엔드포인트**가 담당.
```text
인터넷
 │ inbound(현관)        outbound(나가기)
 ▼                          ▲
[Public Subnet] ALB ── NAT Gateway
                          │
[Private Subnet] 앱/DB : 공인 IP 없음, NAT로 나가기만·밖에서 직접 못 들어옴
```
| 방향 | 담당 | 역할 |
|---|---|---|
| 밖→안(inbound) | Internet Gateway + ALB | 사용자 요청 받기 |
| 안→밖(outbound) | **NAT Gateway** | private 인스턴스가 인터넷 나가기(내부 숨김 + inbound 차단) |

- 한 줄: NAT = **private 인스턴스가 "나가기만" 하게 하는 장치**(내부 IP 숨김 + 밖에서 먼저 못 들어옴).
- 💸 NAT Gateway는 시간당 + 데이터 처리 요금 → 실습에서 무심코 만들면 비용(2교시 비용 사고 예시 참고).

### EBS는 gp3가 기본값 (질문에서 나온 것)
EBS 범용 SSD는 `gp2` → `gp3`로 세대가 올라감(gp1은 없음). **특별한 이유 없으면 gp3.**
| | gp2 (구세대) | gp3 (신세대) |
|---|---|---|
| 성능-용량 | IOPS가 용량에 묶임(3 IOPS/GB) | **분리됨**(용량 무관) |
| 기본 성능 | 작은 볼륨은 IOPS도 작음(버스트) | **기본 3,000 IOPS + 125 MB/s 보장** |
| 성능 추가 | 용량을 키워야 함(낭비) | IOPS·처리량만 따로 증설 |
| 가격 | 기준 | **약 20% 저렴** |

- 핵심: gp3가 **더 싸고**, 작은 디스크에도 **기본 3000 IOPS**, **성능을 용량과 분리**. gp2 볼륨도 gp3로 무중단 전환 가능.
- 다른 타입: `io1/io2`(초고 IOPS 대형 DB), `st1`(처리량 HDD·로그), `sc1`(콜드 HDD 최저가). 특수 경우 아니면 gp3로 충분.

### Session Manager로 22포트 안 열고 접속 (질문에서 나온 것)
EC2 콘솔 **[연결]** → **Session Manager** = SSH 키·터미널 없이 **브라우저(또는 CLI)로 셸 접속**. 정식명 AWS Systems Manager(SSM) Session Manager.
| | 전통 SSH | Session Manager |
|---|---|---|
| 인바운드 포트 | **22 열어야** | **아무것도 안 염** ⭐ |
| 키 | SSH 키페어 필요 | 불필요 |
| 통로 | 공인 IP + 22 | 인스턴스가 **아웃바운드 443**으로 SSM에 연결 |
| 권한/감사 | 키 소유 | **IAM 권한** 제어 + CloudTrail/CloudWatch 자동 기록 |

**22포트 위험**: SSH 22는 유명해서 봇이 24시간 스캔·brute-force. SG에서 `22`를 `0.0.0.0/0`로 열면 공격 표적 → 열어야 하면 **내 IP만(`내IP/32`)**, 되도록 **SSM으로 대체**.
```text
전통 SSH : 인터넷 → [SG 22 열림] → EC2   ← 공격 표면
SSM      : EC2 → (아웃바운드 443) → SSM → 브라우저   ← 인바운드 0
```
**쓰려면 조건 3개**: ① 인스턴스에 SSM Agent(최신 AMI 기본 탑재) ② IAM Role(`AmazonSSMManagedInstanceCore`) 부착 ③ SSM endpoint로 아웃바운드 443. 안 맞으면 [연결]의 Session Manager 탭 비활성 → 이 3개 확인.

### 한 줄 요약
AWS에서 resource를 못 찾으면 **이름보다 Region을 먼저** 확인한다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| 서울에서 만들고 다른 Region 화면을 봄 → resource 없음 | Region selector + resource ARN/URL의 region 값 확인. 삭제 아니라 조회 Region 불일치 |
