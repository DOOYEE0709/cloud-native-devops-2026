# 5교시: 장점, 단점, 많이 쓰이는 분야

## 핵심 정리

### 장점과 단점은 같은 지점(control plane + reconciliation)에서 나온다
| 장점 | 운영 효과 |
|---|---|
| 표준 API | workload/network/config/secret을 공통 방식으로 표현 |
| 자동 복구 | controller가 desired state 유지 |
| 배포 전략 | rollout/rollback을 API로 |
| 확장성 | replica·autoscaling 모델 |
| 생태계 | Helm, Argo CD, Prometheus, Ingress controller 등 |

| 단점 | 운영 부담 |
|---|---|
| 러닝커브 | object·controller 개념이 많음 |
| YAML 복잡도 | 선언이 틀리면 상태도 틀어짐 |
| 디버깅 난도 | API object·event·log·node를 함께 봐야 |
| 비용 | node idle resource·observability 비용 |
| 보안 | RBAC·Secret·image policy·network policy 필요 |

### 많이 쓰이는 분야
- **MSA**(서비스 많고 독립 배포) / **SaaS**(tenant·region별 배포 표준화) / **Platform Engineering**(공통 배포 플랫폼) / **CI/CD Preview**(PR별 임시 환경) / **Data/ML Serving**(batch·GPU) / **Edge·On-prem** / **Hybrid·Multi-cloud**.

### Managed Kubernetes (control plane을 클라우드가 대신 운영)
> 💡 강의 그림 맨 아래 원형에 있던 로고 3개 = **3대 클라우드의 관리형 K8s**.

| 클라우드 | 서비스 | 풀네임 | 로고 |
|---|---|---|---|
| **AWS** | **EKS** | Elastic **K**ubernetes **S**ervice | AWS 로고 |
| **Azure** (MS) | **AKS** | **A**zure **K**ubernetes **S**ervice | Azure 로고 |
| **Google** (GCP) | **GKE** | **G**oogle **K**ubernetes **E**ngine | 구글 로고 |

- 외우는 법: AWS·Azure는 **K**ubernetes **S**ervice(-KS), 구글만 Kubernetes **E**ngine(-KE).
- managed를 쓰면 **control plane 운영 부담 일부가 줄어듦**. 하지만 **workload·node capacity·network·IAM/RBAC·비용·배포 정책은 여전히 팀 책임.** (= "다 떠넘기는 것" 아님)
- 1교시 ECS/EKS 정리와 연결: EKS = "표준 K8s를 AWS가 대신 운영"하는 그것.

### 회사에서 자주 나오는 구조 (Day3 ↔ Day4~5 연결)
```text
GitHub Actions → Docker image push → GitOps repo manifest update
   → Argo CD/Flux sync → K8s Deployment rollout → Prometheus/Grafana/Log 확인
```

### K8s에 "안 올릴 수도" 있는 것 (전부 올리는 게 정답 아님)
| 대상 | 대안(managed) |
|---|---|
| 운영 DB | RDS, Cloud SQL |
| Redis/cache | ElastiCache, Memorystore |
| Object storage | S3/GCS/Azure Blob |
| 단순 static site | CDN/static hosting |
| 매우 작은 내부 도구 | VM, Compose, PaaS |
- 핵심 역량 = **"무엇을 cluster에 올리고 무엇을 managed로 뺄지 판단하는 능력."**

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Kubernetes use case는? | MSA, SaaS, Platform Engineering, CI/CD preview, Data/ML serving 등 |
| managed service 대안은? | DB→RDS/Cloud SQL, cache→ElastiCache, storage→S3/GCS 등 |
| cluster에 올릴 것은? | 자주 배포·확장·복구가 필요한 stateless app, MSA 서비스 |
| managed/external로 둘 것은? | 운영 DB·cache·object storage·static site 등 |
| 3대 managed K8s는? | AWS EKS, Azure AKS, Google GKE |

## notes

### Observability와 비용 (강사님: 클라우드에선 Prometheus만으론 부족, 비용 생각해야)

**핵심: Prometheus는 observability의 일부일 뿐**
- Observability = **3가지 기둥**, Prometheus는 그중 metrics만.

| 기둥 | 무엇 | Prometheus? | 별도 도구 |
|---|---|---|---|
| **Metrics**(지표) | CPU·메모리·요청수 등 숫자 | ✅ Prometheus 영역 | — |
| **Logs**(로그) | app이 찍는 텍스트 기록 | ❌ | Loki, ELK, CloudWatch Logs |
| **Traces**(분산추적) | 요청이 A→B→C 거치는 경로 | ❌ | Jaeger, Tempo, X-Ray |

→ "Prometheus만으론 수집 안 되는 부분 있다"는 **맞음** (로그·트레이스는 별도 필요).

**Prometheus 자체도 규모 커지면 한계**
- 장기 보관 약함(로컬 디스크 기본 → Thanos/Cortex/Mimir 필요), 다중 cluster·high cardinality 시 무거워짐.
- 그래서 클라우드는 보통 **managed observability** 사용: AWS CloudWatch·**AMP(Amazon Managed Prometheus)**·X-Ray, 또는 Datadog·Grafana Cloud·New Relic.

**그래서 비용 (강사님 포인트)**
```text
관측 데이터(특히 로그·고카디널리티 지표)
  → 수집(ingestion) + 저장(storage) + 보관기간(retention) = 전부 돈
```
- **로그가 특히 비쌈**(양이 많음). Datadog 등 SaaS는 호스트당/데이터량당 과금 → cluster 커지면 비용 급증.
- 5교시 단점 표의 **"비용 = node idle resource + observability 비용"**이 바로 이 얘기.

> 한 줄: **Prometheus는 metrics만. logs·traces까지 보려면 observability 스택이 더 필요하고, 클라우드선 그게 managed/SaaS라 수집·저장·보관 비용이 든다. → "무엇을 얼마나 관측할지"를 비용과 함께 판단.**

### Argo CD = cluster에 직접 명령 안 쳐도 되는 GitOps 도구

**기존 방식 vs Argo CD**
```text
[기존]  사람이 → kubectl apply → cluster      (매번 손으로 직접 명령)

[Argo CD] 사람은 → Git repo에 YAML push 만
                       │
              Argo CD가 Git을 감시(watch)
                       │
              Git ↔ cluster 차이 발견 → 자동 적용(sync)
```
- 사람은 **cluster를 직접 안 건드림.** Git에 올리기만 하면 Argo CD가 알아서 반영.

**핵심: K8s reconciliation을 Git까지 확장한 것**

| | desired state | current state | 누가 맞춤 |
|---|---|---|---|
| K8s 내부 | etcd의 object | cluster 실제 상태 | controller |
| **Argo CD** | **Git repo의 YAML** | cluster 실제 상태 | **Argo CD** |

→ Argo CD = **"GitOps controller"** (4교시 desired/current 원리와 동일).

**"안 쳐도 된다"의 장점**
- 사람이 cluster에 직접 명령 X → 실수·권한 노출 ↓
- **Git = single source of truth** → 변경 이력 추적이 Git history로
- **롤백 = Git revert** → 이전 커밋으로 되돌리면 cluster도 자동 복구
- 여러 사람/여러 cluster에 동일하게 적용

**위 GitOps 파이프라인과 연결**
```text
GitHub Actions(빌드·push) → GitOps repo manifest update
   → Argo CD sync(자동, Git→cluster) → K8s Deployment rollout
```
- 비슷한 도구: **Flux** (둘 다 GitOps controller).

> 한 줄: **Argo CD = Git에 올리기만 하면 cluster에 직접 명령 안 쳐도 자동 배포·동기화해주는 GitOps 도구.**

### 용어: stateful vs stateless

> **state = 상태/데이터.** stateful = 데이터를 **기억함** / stateless = 데이터를 **안 기억함**(처리하고 까먹음).

| | stateless | stateful |
|---|---|---|
| 비유 | **자판기** (누가 왔는지 기억 X) | **일기장** (내용이 계속 쌓임) |
| 예시 | nginx, API 서버 | **DB**, Redis, 파일 저장소 |
| 죽으면? | 새로 띄우면 끝 (잃을 것 없음) ✅ | 데이터 사라질 위험 ⚠️ |

- **구분법**: "이거 죽었다 켜면 데이터가 사라지나?" → 사라져도 되면 stateless, 안 되면 stateful.
- K8s 강점(자동 재시작·재배치·replica 복제)은 **잃을 데이터가 없는 stateless라서** 마음껏 가능. stateful은 그 자동화가 오히려 위험 → 조심.

### 왜 DB는 K8s에 잘 안 올리나 (강사님: 백업·장애 때문, 비용 더 듦)

**핵심: K8s는 stateless workload를 전제로 설계됨. DB는 stateful.**

| K8s 특징 | stateless app엔 장점 | **DB엔 위험** |
|---|---|---|
| Pod 죽으면 자동 재생성/이동 | 복구 빠름 | 스토리지 못 따라가면 데이터 유실·손상 |
| 아무 node에나 재배치 | 유연 | DB는 디스크에 묶여 함부로 옮기면 깨짐 |
| replica 늘려 복제 | 부하 분산 | 그냥 복제하면 데이터 불일치·split-brain |
| controller가 알아서 재시작 | self-healing | 잘못 재시작하면 트랜잭션 깨짐 |

→ 4교시 self-healing 한계와 연결: **controller는 Pod 개수는 맞춰도 데이터 일관성·트랜잭션까지는 책임 못 짐.**

**"K8s 내에서 할 수 있는 게 없다" 정확히 하면**
- 올릴 수는 있음(StatefulSet·PersistentVolume·DB Operator 존재).
- 하지만 DB가 진짜 필요로 하는 **백업·시점복구(PITR)·자동 failover·복제·패치**를 K8s가 이해 못 함. K8s는 "Pod 몇 개"만 알지 "데이터가 일관적인가"는 모름.
- → 직접 하려면 DB 전문운영 + Operator + 스토리지 설계를 팀이 다 떠안음 (위험·고비용).

**그래서 비용**
```text
선택1. K8s에 직접 DB 운영 → 백업·failover·복제를 팀이 직접 책임 → 인건비·장애 리스크 ↑↑
선택2. Managed DB(RDS, Cloud SQL) → 백업·failover·패치 자동 → 서비스 요금 ↑ (안정성↑·운영부담↓)
```
- 어느 쪽이든 **stateless app보다 비용이 더 든다** → 그래서 5교시 표에서 운영 DB는 **RDS/Cloud SQL로 빼라**고 한 것.

> 한 줄: **DB는 stateful이라 K8s의 자동 재시작·재배치·복제가 오히려 데이터 손상 위험. 백업·복구·failover를 K8s가 이해 못 하므로 보통 managed DB로 빼고, 그만큼 비용이 더 든다.**

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
