# 1교시: Kubernetes 탄생 배경과 Cluster 운영 문제

## 핵심 정리

### Kubernetes는 무엇인가
- "container 실행 명령을 편하게 모아둔 도구"가 아니다.
- **여러 machine 위에서 수많은 workload를 계속 실행 상태로 유지하는 cluster orchestration platform.**

### 왜 필요한가 (규모가 커지면 생기는 질문)
- 서버 100대, 서비스 300개, 매일 수십 번 배포라면?
- 서버 하나가 죽으면 누가 옮겨 띄우나?
- 배포 중 절반만 실패하면 어떻게 되돌리나?
- → cluster scheduler / orchestrator가 필요해진다.

### Container만으로 부족한 점
- Docker는 **container 실행의 표준**(image, port, env, volume, network)을 만들었다.
- 하지만 어디 배치할지 / 몇 개 유지할지 / 죽으면 복구 / traffic 라우팅 / rollout 제어 / 전체 상태 저장에는 답하지 못한다.
- → Kubernetes는 **containerized workload 운영의 표준 API**를 만든다.

### 핵심 발상: Desired State
> Kubernetes는 cluster의 desired state를 저장하고,
> current state를 관찰하며,
> 둘의 차이를 줄이기 위해 계속 조정하는 시스템이다.
- 이걸 가능하게 하는 게 control plane + controller loop.
- 이 문장이 잡혀야 API Server, etcd, Scheduler, Controller Manager, kubelet이 따로 놀지 않는다.

### Docker Swarm vs Kubernetes (강사님 코멘트)
- Docker에도 **swarm mode**(자체 오케스트레이션)가 있다.
- 그런데 Kubernetes가 cluster scale in/out(늘리고 줄이기), 네트워크 분리 등이 훨씬 잘 되어 있다.
- 그래서 현업에서는 Swarm보다 Kubernetes를 쓴다.
- 강사님 주변도 "Swarm 써본 적 있다" 정도지 거의 안 쓴다. → **사실상 표준은 Kubernetes.**

### 배경
- Google 내부 Borg/Omega 같은 cluster management 경험이 배경.
- 그 문제의식을 open source 생태계에서 다룰 수 있게 만든 프로젝트가 Kubernetes.

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Kubernetes가 등장한 운영 문제는? | 대규모 cluster에서 배치/용량/복구/발견/배포/격리/관찰 문제 |
| container만으로 부족한 점은? | 배치·복제·복구·discovery·rollout·상태저장을 container 단독으로 못 함 |
| desired state란? | 원하는 상태를 선언하면 K8s가 current state와 차이를 줄여 맞춘다 |
| 왜 Swarm 대신 K8s? | scale in/out, 네트워크 분리 등이 잘 되어 있어 사실상 표준 |

## notes

### Q&A: AWS ALB로도 트래픽 제어 되는데, 그 기능이 K8s에 내장된 거냐?

**질문 (수강생)**
- AWS를 먼저 배워서 그런지, Docker로 여러 서버 올리고 **ALB** 쓰면 트래픽을 알아서 분산/제어해주지 않나?
- 그런 기능이 Kubernetes에는 내장되어 있다는 뜻인가?

**답변 (강사님)**
- 그렇게도 **가능은 하다.** (ALB + 서버 조합으로 트래픽 제어 가능)
- 다만 **AWS 네이티브 기능이 다 좋은 건 아니다.**
  - 컨테이너 오케스트레이션 옵션: **ECS, EKS, Elastic Beanstalk** 등 → 이 중엔 ECS, EKS가 가장 낫다.
- **ALB도 좋지만 한계가 있다.**
  - **Secret(시크릿)** 관리, **인증서(certificate)** 처리 등에서 제약/불편한 부분이 있다.
  - Kubernetes에 비해 단점이 존재.
- AWS 같은 클라우드에는 **비표준적인 방법들**이 섞여 있어서, **상황을 잘 보고 골라야 한다.**
- 그래서 클라우드에서 K8s를 쓸 때 **ALB와 콤비네이션으로 같이 쓰기도 한다.**

**핵심 관점**
- 판단 기준 = **"혼자 일한다면 이 클러스터들을 어떻게 관리할까?"** 의 **편의성**.
- ALB·Secret·인증서·배포·복구를 각각 따로 챙기는 불편함을 **하나로 묶어서 표준 API로 해결**해주는 게 Kubernetes.
- 즉 ALB가 해주는 트래픽 분산은 K8s에선 Service/Ingress 등으로 **운영 전체의 일부로 통합**되어 있다는 뜻.

**정정/보강 (내가 잘못 듣거나 정리했을 수 있어서 직접 찾아본 내용)**
> ⚠️ 아래는 수업 중 내가 받아적은 메모를 나중에 직접 확인·검색해서 보강한 것. 강사님 원래 표현과 다를 수 있음(내 메모 기준 정정).

- "ALB가 **인증서**가 제약적이다"라고 적었는데, 찾아보니 → 절반만 맞음.
  - 공개 TLS 인증서는 ALB + **ACM**이 자동 발급·자동 갱신이라 오히려 **가장 쉬운 축**(= ALB의 강점).
  - 제약이 생기는 건: ACM 인증서 **export 불가**(AWS 안에서만), 서비스 간 **mTLS**, 클러스터 내부 통신, 멀티클라우드/온프레 **이식성** → 이건 K8s의 **cert-manager**가 더 유연.
- "ALB가 **Secret**이 약하다"라고 적었는데, 찾아보니 → 비교 대상이 어긋남.
  - ALB는 시크릿 매니저가 아님. AWS에선 **Secrets Manager / SSM Parameter Store**가 그 역할.
  - K8s는 **Secret 오브젝트 + External Secrets**로 워크로드에 표준 주입.
- 직접 확인한 결론: "ALB가 약하다"기보다 **"K8s는 트래픽·시크릿·인증서·배포·복구를 하나의 표준 API로 묶어 준다"**가 핵심. 강사님의 **방향성·결론 자체는 사실**.

### 용어 정리: ECS / EKS / Elastic Beanstalk / Ingress (자꾸 헷갈리는 것)

**전제: 이 셋은 "어디서 컨테이너를 굴릴까"의 선택지 (AWS 컨테이너 오케스트레이션)**

| 서비스 | 한 줄 정의 | 표준? | 특징 |
|---|---|---|---|
| **ECS** (Elastic Container Service) | AWS **전용** 컨테이너 오케스트레이터 | ❌ AWS 종속 | 간단·관리 부담 적음. K8s 안 배워도 됨. 단 AWS 밖으로 이식 불가 |
| **EKS** (Elastic Kubernetes Service) | AWS가 운영해주는 **관리형 Kubernetes** | ✅ K8s 표준 | control plane을 AWS가 관리. 표준 K8s라 이식성 좋음. 대신 K8s 학습 필요 |
| **Elastic Beanstalk** | 코드 올리면 인프라(EC2·LB·오토스케일)를 **알아서 깔아주는** PaaS | ❌ | 가장 추상화↑·제어↓. 빠른 배포용. 요즘은 레거시 취급, 컨테이너는 ECS/EKS로 감 |

- 쉽게: **Beanstalk = 제일 자동(제어 약함)** → **ECS = AWS식 컨테이너 운영** → **EKS = 표준 K8s를 AWS가 대신 운영**.
- 오케스트레이터(ECS/EKS/Beanstalk)는 **"누가 컨테이너를 배치·유지하느냐"** 의 문제.

**Ingress 는 위 셋과 종류가 다름 (Kubernetes **안**의 개념)**
- **Ingress** = K8s 클러스터로 **들어오는 외부 HTTP(S) 트래픽을 라우팅하는 규칙(오브젝트).**
  - 예: `/api` → api 서비스, `/web` → web 서비스, 도메인별 분기, TLS 종료.
- Ingress는 **규칙(설계도)일 뿐**, 실제로 트래픽을 처리하는 건 **Ingress Controller**.
  - EKS에서는 **AWS Load Balancer Controller**가 Ingress를 읽어서 **실제 ALB를 자동 생성/설정**함. → 강사님이 말한 "K8s + ALB 콤비"가 바로 이거.
- 정리: **ECS/EKS/Beanstalk = "어디서 굴릴까"**, **Ingress = "들어오는 트래픽을 어떻게 나눌까"**. 층위가 다르다.

```text
[사용자 트래픽]
      │
   ALB (실제 로드밸런서)
      │  ← AWS Load Balancer Controller가 자동 생성
 Ingress (라우팅 규칙: 경로/도메인별 분기, TLS)
      │
  Service (안정적 진입점)
      │
Pod / Pod / Pod (실제 컨테이너)   ← EKS(K8s)가 배치·유지
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
