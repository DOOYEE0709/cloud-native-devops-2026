# 1교시: Week4 요약 + AWS로 넘어가는 이유

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| AWS 수업의 첫 질문은? | "무엇을 만들까"가 아니라 "어느 계정·Region·권한·비용 경계에서 만들까" |
| Kubernetes와 AWS 역할 차이는? | K8s=cluster 안 workload 조율, AWS=cluster 밖 compute/network/storage/identity/observability/cost 경계 제공 |
| Service/Ingress를 ALB/VPC와 같은 계층으로 보면? | 오해. managed K8s도 결국 AWS resource 위에서 돌기 때문에 경계를 따로 봐야 함 |
| 오늘 resource를 많이 안 만드는 이유는? | 잔여 비용·권한 상태가 학생마다 달라져 다음 날 수업이 흔들림. 첫날은 안전장치+resource map 먼저 |
| Region이 다른데 resource가 안 보이면? | 콘솔 오른쪽 위 **Region selector**부터 확인 (resource 조회 기준) |

## notes

### 오늘 반드시 가져갈 것
| 필수 개념 | 왜 필수인가 | 놓치면 |
|---|---|---|
| Cloud resource boundary | 모든 resource가 계정·Region·권한·비용 경계 안에서 생성됨 | 어디서 비용 나는지 모름 |
| K8s vs AWS 역할 | K8s=cluster 안 조율, AWS=cluster 밖 자원 제공 | Service/Ingress를 ALB/VPC와 혼동 |
| Evidence-first | 클릭보다 생성 전/후 증거가 중요 | 장애·비용 질문에 답 못 함 |

### Week4에서 AWS로 이어지는 질문
| Kubernetes에서 본 것 | AWS에서 다시 묻는 질문 |
|---|---|
| Node capacity | node는 어떤 EC2/managed compute 위에서 도나 |
| Service/Ingress/Gateway | 외부 LB·public endpoint는 누가 만들고 비용은 어디서 나나 |
| Secret/ConfigMap | cloud secret store/parameter store는 어디에 |
| PV/PVC | 실제 disk·object storage·managed DB는 어떤 service |
| metrics/logs/events | CloudWatch, CloudTrail, billing은 어디서 보나 |
| RBAC/Kyverno | AWS IAM·resource policy는 어떤 경계에서 막나 |

### Computing spine에 붙여 읽기
```text
Local process → Docker container → Kubernetes workload → AWS resource boundary → Cost/IAM/Logs/Audit
```
| Spine | 대표 service | 관찰 질문 |
|---|---|---|
| Compute | EC2, ECS, Lambda | 어떤 실행 단위가 돈을 쓰나 |
| Network | VPC, subnet, SG, ALB | 누가 어디서 접속 가능한가 |
| Storage | S3, EBS, EFS | 데이터가 resource 삭제와 함께 사라지나 |
| Database | RDS | 누가 DB port에 접근 가능한가 |
| Identity | IAM, MFA, role | 누가 생성/삭제 권한을 갖나 |
| Observability | CloudWatch, CloudTrail | 로그/지표/API 이벤트를 어디서 보나 |
| Cost | Billing, Budget, Cost Explorer | 언제부터 비용이 생기고 알림은 |

오늘은 service 이름을 다 외우는 시간이 아니라 **spine에 붙여서 "어느 경계인가"를 읽는** 연습이다.

### IaaS / PaaS / SaaS — 관리 책임을 얼마나 넘기나 (질문에서 나온 것)
KT Cloud·AWS EC2는 **IaaS**. "어디까지 내가 관리하고 어디부터 provider가 관리하나"로 나뉜다.
```text
        내가 관리 ←──────────────→ provider가 관리
온프레미스 : 서버·네트워크·OS·런타임·앱  전부 내가
IaaS      : OS·런타임·앱 내가 / 서버·네트워크·가상화는 provider
PaaS      : 앱·데이터만 내가  / OS·런타임까지 provider
SaaS      : 그냥 쓰기만       / 전부 provider
```
| 모델 | 뜻 | 예시 | 비유 |
|---|---|---|---|
| IaaS | 인프라(가상서버·네트워크·스토리지) 빌림 | **KT Cloud, EC2·VPC·EBS·S3** | 골조 빌려 내가 인테리어 |
| PaaS | 앱 올릴 플랫폼(OS·런타임 관리 안 함) | RDS, Elastic Beanstalk, Fargate | 가구 된 사무실 |
| SaaS | 완성된 SW 그냥 씀 | Gmail, Slack | 호텔 체크인 |

**한 provider(AWS)가 세 계층을 다 제공** — 서비스마다 계층이 다르다:
| AWS 서비스 | 계층 |
|---|---|
| EC2·VPC·EBS·S3 | IaaS(인프라 primitive) |
| RDS·Elastic Beanstalk·ECS/EKS Fargate | PaaS(관리형) |
| Lambda | FaaS(서버리스, PaaS 세분) |

→ spine 표의 EC2/VPC/EBS가 IaaS 층. 위로 갈수록(RDS·Fargate·Lambda) **관리 책임을 AWS에 넘김**. 앞서 본 **관리 부담 vs 비용/자유도** 트레이드오프가 그대로 적용.

### 대표 service 하나씩 (수업 중 짚은 것)
| service | 정체 | 핵심 / 교정 |
|---|---|---|
| **EC2** | 가상 **서버**(VM) | OS부터 내가 관리하는 실행 단위. "가상 서비스"가 아니라 가상 서버 |
| **ECS** | AWS 자체 컨테이너 오케스트레이터 | Kubernetes 아님. k8s가 과할 때 실무에서 자주 씀(특히 Fargate) |
| **Lambda** | 서버리스 함수 | 이벤트 올 때만 실행, 쓴 만큼만 과금 |
| **EKS** | Managed Kubernetes | 결국 **EC2 위에 k8s control plane**을 얹은 것 → compute 기초는 EC2라 대표 표엔 EC2를 둠 |
| **ALB** | Application Load Balancer(L7) | 요청을 여러 target(EC2·컨테이너)으로 **분배**. VPC 안(subnet)에 배치. K8s Service/Ingress가 실제로 만드는 것 |
| **SG (Security Group)** | 가상 **방화벽** | ⚠️ **시크릿 관리 아님!** EC2/ENI 단위로 인바운드/아웃바운드(포트·IP) 허용/차단. K8s NetworkPolicy에 해당. 시크릿은 Secrets Manager/Parameter Store가 별도 |
| **EBS** | 블록 스토리지(가상 디스크) | 보통 한 인스턴스에 붙음. K8s PV(블록) |
| **EFS** | Managed NFS(파일) | 여러 인스턴스 동시 마운트. EBS보다 GB당 비쌈(점점 빨라짐). K8s RWX PV |
| **S3** | 오브젝트 스토리지 | 인스턴스에 안 붙고 HTTP API로 접근. 가장 저렴 |
| **FSx** | 고성능 파일시스템 | Windows/Lustre용. 수업에선 안 깊게(우리는 S3/EBS/EFS 위주) |

### 스토리지 3종 비교 (자주 헷갈림)
| | EBS | EFS | S3 |
|---|---|---|---|
| 타입 | 블록(디스크) | 파일(NFS) | 오브젝트 |
| 붙는 수 | 보통 1 인스턴스 | 여러 인스턴스 동시 | 인스턴스 안 붙음(HTTP) |
| 비유 | 노트북 SSD | 공유 폴더(NAS) | 파일 업로드 버킷 |
| 가격 | 중 | 높음 | 낮음 |

> ⭐ 핵심 교정: **SG = 네트워크 방화벽(포트/IP 접근 제어)**, 시크릿 저장소가 아니다.

### 리버스 프록시와 ALB 관계 (질문에서 나온 것)
**리버스 프록시** = 클라이언트 요청을 대신 받아 뒤의 실제 서버로 넘겨주는 중간 서버(서버 앞단).
```text
사용자 → [리버스 프록시] → 실제 서버(들)
```
- 하는 일: 로드밸런싱, SSL 종료, 캐싱, 경로별 라우팅(`/api`→A, `/img`→B), 백엔드 IP 숨김.
- 대표: **Nginx / HAProxy / Envoy**. 사실 우리가 본 nginx(gitops-web), **Istio Envoy sidecar**, **K8s Ingress**가 다 리버스 프록시.
- cf. 포워드 프록시=클라이언트 쪽에서 대신 나감(회사 방화벽), 리버스=서버 앞에 서서 대신 받음.

**ALB와 같이 쓰나? → 흔하게 2단으로 같이 쓴다.** 역할·경계가 다르기 때문.
```text
사용자 → ALB(바깥, AWS managed) → 리버스 프록시/Ingress(안쪽, 내가 관리) → 실제 앱
```
| | ALB | 리버스 프록시(Nginx/Ingress/Envoy) |
|---|---|---|
| 위치 | AWS 인프라 경계(VPC 진입점) | 앱/클러스터 안 |
| 관리 주체 | AWS managed | 내가 관리 |
| 주 역할 | 인터넷 진입·AZ 분산·health check·WAF·인증서 | 세밀한 라우팅·앱별 규칙·서비스 메시 |
| 확장 | AWS 자동 | 내가 파드/서버 수 조절 |

- 전형적 EKS 조합: 인터넷 → **ALB** → **Ingress Controller(Nginx/Envoy)** → 파드.
- ALB 규칙은 경로/호스트 정도로 제한적 → 복잡한 라우팅·리라이트·미들웨어는 **안쪽 프록시**가 담당.
- 정리: ALB=바깥쪽 managed 진입 LB, 리버스 프록시=안쪽 세밀 제어. 겹치는 게 아니라 **바깥→안쪽 2단 구조**.

### 실행 방식과 비용 약정 (질문에서 나온 것)
**EKS 노드 방식: EC2 노드 vs Fargate** — Fargate는 노드(EC2) 없이 파드를 서버리스로 실행(AWS가 노드 관리).
| | EC2 노드 | Fargate |
|---|---|---|
| 유리한 경우 | 꾸준히 높은 부하, 노드를 꽉 채워 씀 | 간헐적/변동 부하, 짧게 뜨는 작업 |
| 과금 | 노드 시간(파드 없어도 켜지면 과금) | 파드 vCPU·메모리(쓴 만큼) |
| 단점 | idle 용량 낭비, 관리 부담 | 단가 비쌈, bin-packing 불가 |

→ **꽉 채워 오래 = EC2 유리, 띄엄띄엄/예측 어려움 = Fargate 유리.** baseline은 EC2, 스파이크는 Fargate로 섞는 패턴. (Fargate는 ECS/EKS 둘 다 가능, DaemonSet·GPU·일부 볼륨 제약 있음)

**비용 약정 3단**
```text
온디맨드            : 약정 없음, 제일 비쌈, 언제든 끔
Savings Plans / RI : 1·3년 약정 → 할인 (꾸준한 baseline)
Spot               : 남는 용량 초저가(최대 90%↓), 회수될 수 있음 (내결함성 워크로드)
```

**RI (Reserved Instance)** — 1/3년 약정으로 온디맨드 대비 최대 ~72% 할인. 대상: EC2, RDS, **ElastiCache**, Redshift, OpenSearch 등. 특정 인스턴스 타입/조건에 묶인 **청구서 할인** 개념(Standard=유연성↓, Convertible=타입 변경 가능).

**SP (Savings Plans)** — "시간당 $ 사용액"을 1/3년 약정. RI보다 유연.
| | RI | Savings Plans |
|---|---|---|
| 약정 대상 | 특정 인스턴스 타입/스펙 | 시간당 $ 사용액 |
| 유연성 | 낮음(타입 묶임) | 높음(타입·리전, EC2↔Fargate↔Lambda 넘나듦) |
| 종류 | Standard / Convertible | Compute SP / EC2 Instance SP |

→ 유연성 때문에 요즘은 **Savings Plans 권장**. 특히 **Compute SP**는 EC2·Fargate·Lambda에 다 적용돼 "노드냐 Fargate냐" 선택과도 맞물림.

### 약정 못 채우면? — use-it-or-lose-it (질문에서 나온 것)
약정 금액은 **쓰든 안 쓰든 낸다.** 시간 단위로 정산되고 **못 채운 만큼은 이월 없이 소멸**.
```text
약정 $10/시간
어느 시간 $7만 씀  → $10 청구 (남은 $3 날아감, 이월 X)
어느 시간 $13 씀   → $10 할인가 + 초과 $3 온디맨드 청구
```
**전략: peak가 아니라 "항상 쓰는 baseline"에만 약정.**
```text
        ┌── 스파이크 → 온디맨드/Fargate/Spot로 처리
사용량  │▓▓▓░░░░
        │▓▓▓▓▓▓▓  ← baseline만 Savings Plans 약정
        └──────── 시간
```
| 약정 수준 | 결과 |
|---|---|
| 너무 많이 | 못 채워 낭비(소멸) |
| 너무 적게 | 초과분 온디맨드 정가 |
| **baseline만** ✅ | 낭비 0, 스파이크만 온디맨드 |

**중간에 필요 없어지면(부분 탈출구):** Standard RI=Marketplace에 되팔기 가능 / Convertible RI=타입 교환 가능 / **Savings Plans=취소·환불·판매 불가**(그래서 더 보수적으로). 

### ⭐ compute 축 vs 요금 축은 별개다 (자주 헷갈림)
"ECS 쓰면 온디맨드보다 싸지나?" → **비교 자체가 성립 안 함.** 축이 2개다.
```text
축1) 무엇으로 돌리나(compute) : EC2 / ECS·Fargate / EKS / Lambda
축2) 어떻게 과금하나(pricing) : 온디맨드 / Savings Plans·RI / Spot
```
ECS는 축1, 온디맨드는 축2. **ECS도 결국 EC2/Fargate 위에서 돌고, 그 아래 compute가 온디맨드/SP로 과금**된다. 즉 "ECS로 바꿔서 싸게"가 아니라 **"약정(SP/RI)으로 싸게"**가 맞다.

**24/7 웹서버(항상 켜짐, 예측 가능) 비용 최적화**
| 방법 | 적합 | 이유 |
|---|---|---|
| 온디맨드 | ❌ 비쌈 | 약정 없어 정가 |
| **Savings Plans / RI** | ✅ 정답 | 계속 켤 거니 1·3년 약정 → 최대 ~72%↓ |
| Spot | ❌ 위험 | 갑자기 회수 → 웹서버 죽으면 안 됨 |

**compute 선택(축1)이 비용에 영향 주는 건 "사용 패턴"에서:**
```text
24/7 꾸준한 웹서버  → EC2 + Savings Plans   (단가 최저)
변동 심한 백엔드    → Fargate(온디맨드라도 idle 노드값 안 나가 이득)
```
> 한 줄: compute 종류(축1)와 요금제(축2)는 **따로** 고른다. 항상 켜두는 건 SP/RI, 들쭉날쭉은 Fargate.

### 정적 웹 vs 백엔드 — 무슨 compute를 쓰나 (질문에서 나온 것)
**정적 웹사이트 → S3** ✅ (서버 연산 불필요한 HTML/CSS/JS/이미지)
```text
사용자 → CloudFront(CDN) → S3(정적 파일)
```
- S3 Static Website Hosting으로 서빙. 앞에 CloudFront 붙이면 CDN·HTTPS·캐싱. 제일 싸고 관리 0.

**백엔드(동적 로직·DB)가 있으면 → compute 필요. 단 "ECS가 유일한 답"은 아님.**
| 옵션 | 언제 |
|---|---|
| Lambda | 요청 가끔, 이벤트성, 서버 관리 싫음 (API Gateway + Lambda) |
| ECS/Fargate | 컨테이너로 상시 돌리는 API, k8s는 과함 |
| EKS | 이미 Kubernetes 쓰거나 복잡한 MSA |
| EC2 | 세밀한 제어·특수 환경 |

**실무 하이브리드(정석): 프론트/백엔드 분리**
```text
정적 프론트 : S3 + CloudFront        (React/Vue 빌드 결과물)
동적 백엔드 : ALB → ECS/Fargate  또는  API Gateway → Lambda
데이터      : RDS / DynamoDB
```
판단 기준: 요청 **가끔**=Lambda, **상시 컨테이너**=ECS/Fargate, **이미 k8s**=EKS. 정적만이면 compute 없이 S3로 끝.

### 💸 사례: Athena 쿼리 하나로 $200 (강사님 경험담)
**Athena** = S3의 데이터를 DB 없이 SQL로 바로 조회하는 서버리스 쿼리 서비스(로그 분석 등).
- **과금 = 스캔한 데이터 양** (`$5 / 1TB scanned`). 결과가 몇 줄이든 **훑은 양**으로 계산.
- 사고: 개발자가 파티션/필터 없이 **1달치 전체를 조회** → 전체 스캔 → **$200**.
- ⚠️ `LIMIT 10`은 소용없다 — WHERE로 안 거르면 전체를 스캔하고 나서 10줄만 보여줌(스캔량 그대로).

**교훈: 필요한 데이터만 조회 = 성능·비용 둘 다 이득**
| 방법 | 효과 |
|---|---|
| 파티셔닝(날짜/지역 폴더 분할) | `WHERE dt='...'`로 해당 폴더만 스캔 — 효과 최대 |
| 컬럼 포맷(Parquet) | 필요한 컬럼만 읽어 스캔량 수십 배↓ |
| 필요 컬럼만 SELECT | `SELECT *` 금지 |
| 압축(gzip/snappy) | 읽는 바이트 ↓ |
| 오래된 데이터 정리·아카이브 | 스캔 대상·저장비 ↓ |

> 쿼리 하나가 계정 비용을 흔든다. 조회 전에 "얼마나 스캔되나"를 의식 — lesson-01의 **evidence-first / 비용 경계 먼저**와 직결.

### 흔한 오해와 교정
| 오해 | 교정 |
|---|---|
| AWS는 서버 빌리는 곳 | compute/network/storage/identity/observability/cost 경계를 조합하는 platform |
| K8s 알면 AWS는 부가지식 | managed K8s도 cloud resource 위에서 동작 → AWS 경계 알아야 함 |
| 첫날 resource 많이 만들어야 진도 | 첫날 진도 = 계정·비용 사고를 막는 운영 기준 만들기 |

### 캡처 주의
credential, account email, MFA code, access key가 안 보이게. Region selector·resource name·tag·상태값처럼 재현에 필요한 값만 남긴다.

### 한 줄 요약
AWS 수업의 첫 질문은 "무엇을 만들까"가 아니라 **"어느 계정·어느 Region·어떤 권한과 비용 경계 안에서 만들까"**이다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| Region 바꿔놓고 resource를 못 찾음 | 콘솔 오른쪽 위 Region selector를 `ap-northeast-2`로 먼저 고정 |
