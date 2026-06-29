# 4교시: 선언적 API와 Reconciliation

## 핵심 정리

### 한 줄 요약
> **Kubernetes는 명령을 한 번 실행하는 시스템이 아니라, 원하는 상태와 실제 상태의 차이를 계속 줄이는 시스템이다.**

### 명령형(imperative) vs 선언형(declarative)
| 명령형 | 선언형 (K8s 방식) |
|---|---|
| "이 container 지금 실행해" | "이 workload는 항상 replica 3개로 유지돼야 한다" |
| "죽었으면 다시 실행해" | "image는 이 버전이어야 한다" |
| "3개로 늘려" | "Ready 아닌 Pod엔 traffic 안 보낸다" |
- 사용자는 **원하는 상태를 API object로 제출**만 함. 실제로 맞추는 건 controller.

### Desired / Current / Reconciliation (3단어)
| 용어 | 의미 |
|---|---|
| **desired state** | 사용자가 API object로 선언한 원하는 상태 |
| **current state** | cluster에서 실제 관찰되는 현재 상태 |
| **reconciliation** | 둘의 차이를 줄이는 **controller loop** |

```text
desired: Deployment replicas=3
current: Ready Pod=2
action:  Pod 1개 추가 생성
```

### Controller Loop = 끝나는 script가 아니라 계속 도는 loop
```text
watch desired → watch current → compare → act → repeat
```
- 대표 controller: Deployment(rollout·ReplicaSet) / ReplicaSet(replica 수) / Job(batch) / Node(health) / EndpointSlice(Service endpoint).

### Self-Healing = 같은 원리
- "Pod 죽으면 K8s가 다시 만든다" = **controller가 desired ↔ current 차이를 발견하고 조정**한다는 뜻.
- ⚠️ 단, **app bug · 잘못된 설정 · DB transaction 불일치까지 자동으로 고쳐주는 건 아니다.**

### Rollout·Scaling도 전부 같은 구조
| 기능 | 내부적으로 보는 것 |
|---|---|
| scale | desired **replicas** 변경 |
| rollout | desired **image/template** 변경 |
| rollback | 이전 desired template으로 되돌림 |
| readiness | current Pod가 traffic 받을 수 있는지 |
- → **기능 이름 외우기보다 desired/current/reconcile 구조를 먼저 잡는 게 핵심.**

### 장점 vs 단점 (이 구조에서 나옴)
| 장점 | 이유 | / | 단점 | 이유 |
|---|---|---|---|---|
| 자동 복구 | loop가 차이 줄임 | | YAML 복잡도 | desired state 정확히 써야 |
| 표준화 | API object로 상태 표현 | | 디버깅 난도 | current가 왜 다른지 추적 |
| GitOps 가능 | YAML을 Git으로 관리 | | 운영 비용 | controller·node·network·storage 함께 봐야 |
| 반복 배포 | rollout/rollback이 API로 | | | |

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| desired state 예시는? | Deployment replicas=3, image=특정버전 등 선언한 원하는 상태 |
| current state 예시는? | 현재 Ready Pod=2 같이 실제 관찰되는 상태 |
| reconciliation이란? | desired ↔ current 차이를 controller loop가 계속 줄이는 것 |
| self-healing 설명은? | Pod 죽으면 controller가 차이 감지 후 다시 생성 (단 app bug까진 못 고침) |
| rollout/scale과의 연결은? | scale=replicas 변경, rollout=image/template 변경 — 전부 desired 변경 + reconcile |

## notes

### 용어: replica가 뭐야?
> **replica = 똑같은 Pod의 복제본.** 같은 app(같은 image/설정)을 여러 개 띄워둔 것.

**왜 여러 개?**
- **부하 분산**: 요청 많으면 Pod 1개로 감당 안 됨 → 여러 개로 나눠 처리
- **고가용성**: 1개 죽어도 나머지가 살아 있어 서비스 안 끊김

```text
Deployment (replicas=3)
   ├── Pod (nginx)   ← replica 1
   ├── Pod (nginx)   ← replica 2
   └── Pod (nginx)   ← replica 3
        ↑ 셋 다 똑같은 복제본
```

**desired/current 구조와 연결 (이 단원 핵심)**
```text
desired: replicas = 3   (3개 원함)
current: Ready Pod = 2  (지금 2개)
action:  Pod 1개 추가 생성  ← ReplicaSet controller가 조정
```
- **scale** = `replicas` 숫자를 바꾸는 것 (3→5면 scale out)
- **self-healing** = Pod 하나 죽어 2개 되면 controller가 1개 더 만들어 3개로 복구
- 이걸 관리하는 게 **ReplicaSet controller**

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
