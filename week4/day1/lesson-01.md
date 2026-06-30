# 1교시: Week3 Kubernetes 2일 요약 + 운영 가능한 Workload 기준

## 핵심 정리

### 질문이 바뀐다 — "띄웠다"(개발자) → "운영 가능하다"(운영자)
- Week3: Pod/Deployment/Service로 **실행**을 확인. Week4 Day1: 그 위에 **운영 기준**을 얹는다.

| Week3 질문 | Week4 Day1 질문 |
|---|---|
| Pod가 뜨는가 | traffic을 받아도 되는 상태인가 |
| Deployment가 replica를 맞추는가 | resource·health 기준을 선언했는가 |
| Service DNS로 접근되는가 | endpoint에서 빠져야 할 Pod를 분리할 수 있는가 |
| 로그를 볼 수 있는가 | metric으로 사용량을 볼 수 있는가 |
| YAML을 적용할 수 있는가 | add-on 설치·변경 이력을 Helm으로 관리하는가 |

### ⭐ "Pod 2개 Running + Service 있음 = 운영 가능?" → "아직 모른다"
- 다음 증거가 아직 없기 때문:

| 아직 모르는 것 | 필요한 증거 |
|---|---|
| 환경별 설정 분리 | ConfigMap, Secret, env 주입 |
| secret이 image/Git에 안 박혀 있나 | Secret 관리·권한 |
| 사용자 받을 준비 됐나 | readinessProbe, endpoint |
| 죽은 process 회복 가능한가 | livenessProbe, restart count |
| node 배치 자원 기준 있나 | requests |
| 폭주 시 상한 있나 | limits |
| 실제 사용량 볼 수 있나 | metrics-server, `kubectl top` |

### 운영 가능한 workload의 최소 기준
| 기준 | K8s 요소 | 왜 필요 |
|---|---|---|
| 설정 분리 | ConfigMap | image 재빌드 없이 환경별 값 변경 |
| 민감정보 분리 | Secret | token/password를 image·Git에서 분리 |
| 준비 상태 | readinessProbe | 준비 안 된 Pod로 traffic 유입 방지 |
| 생존 상태 | livenessProbe | 멈춘 process 자동 재시작 |
| 시작 보호 | startupProbe | 느린 앱이 liveness에 조기 재시작되는 것 방지 |
| 자원 선언 | requests/limits | scheduling·OOMKilled·throttling·비용 판단 |
| 관찰 | metrics-server | CPU/memory 사용량, HPA preview |

### ⭐ Running ≠ Ready
- `STATUS=Running` = container **process가 실행 중**. `READY=1/1` = **probe 기준 traffic 받을 준비됨**.
```text
Running but not Ready
  → process는 떠 있음
  → readinessProbe 실패
  → Service endpoint에서 제외될 수 있음
  → 사용자 traffic 받으면 안 되는 상태
```
- 이 차이를 모르면 "Pod는 떴는데 왜 서비스가 안 되지?"에서 길을 잃는다.

### 운영 사고 진단 순서 — logs부터 보지 마라
```text
새 backend 배포 → Pod Running → 그런데 사용자는 502/timeout
개발자: "Pod 떠 있는데요?"   운영자: "Ready endpoint 있나요?"
```

| 순서 | 명령 | 해석 |
|---|---|---|
| 1 | `kubectl -n week4 get pod` | Running/Ready/Restart 개요 |
| 2 | `kubectl -n week4 get endpoints runtime-api` | Service가 보낼 endpoint 존재? |
| 3 | `kubectl -n week4 describe pod <pod>` | readiness 실패 reason |
| 4 | `kubectl -n week4 logs <pod>` | app process log |
| 5 | `kubectl top pod -n week4` | resource 압박 여부 |

- ⚠️ 자주 놓치는 포인트: **`logs`부터 보는 것.** traffic routing 문제는 **Service·Endpoint·Readiness 증거가 먼저**일 때가 많다. (W3D5 6교시 "DNS 성공≠통신 성공"과 연결)

### manifest의 변화 — 단순 실행 → 판단 기준 주입
```yaml
# W3D5 (단순)
containers:
  - name: nginx
    image: nginx:1.27
    ports: [{ containerPort: 80 }]

# W4D1 (운영 기준 추가)
containers:
  - name: api
    image: hashicorp/http-echo:1.0
    envFrom:
      - configMapRef: { name: api-config }     # 설정 분리
      - secretRef:    { name: api-secret }     # 민감정보 분리
    readinessProbe: { httpGet: { path: /, port: http } }   # 준비 상태
    livenessProbe:  { httpGet: { path: /, port: http } }   # 생존 상태
    resources:
      requests: { cpu: 25m, memory: 32Mi }     # 배치 기준
      limits:   { cpu: 100m, memory: 64Mi }    # 상한
```
- 핵심은 YAML이 길어지는 게 아니라, **Kubernetes에게 판단 기준을 알려주는 것.**

### 오늘의 큰 흐름
```text
기본 workload 배포
  → ConfigMap/Secret 주입 (4교시)
  → readiness/liveness 확인 (5교시)
  → resources 확인 (6교시)
  → Helm으로 metrics-server 설치 (2·3·7교시)
  → kubectl top으로 resource metric 확인 (7교시)
```

### 오늘의 확인 순서
| 순서 | 확인 | 명령 |
|---|---|---|
| 1 | cluster/context | `kubectl config current-context` |
| 2 | workload 상태 | `kubectl -n week4 get deploy,pod` |
| 3 | traffic 준비 | `kubectl -n week4 get svc,endpoints` |
| 4~6 | 상태 이유·config·resource | `kubectl -n week4 describe pod <pod>` |
| 7 | resource metric | `kubectl top pod -n week4` |

### 헷갈리는 표현 정리
| 표현 | 정리 |
|---|---|
| Pod가 떴다 | process가 실행 중이라는 뜻에 가깝다 |
| 서비스가 된다 | Service endpoint·DNS·app response까지 확인 |
| 헬스체크가 있다 | readiness/liveness/startup 중 무엇인지 구분 |
| 리소스를 줬다 | request인지 limit인지 분리 |
| metric이 있다 | metrics-server인지 Prometheus인지 목적 구분 |

### 한 줄 요약
> **앱을 띄우는 것과 운영 가능한 workload를 만드는 것은 다르다.** Running은 개발자 관점, Ready·config·resource·metric은 운영자 관점.

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Running과 Ready의 차이는? | Running=process 실행 중, Ready=probe 통과해 traffic 받을 준비됨. Running이어도 Ready 아니면 endpoint에서 제외 |
| "Pod 2개 Running + Service 있음"이면 운영 가능? | 아직 모름. config·secret·probe·resource·metric 증거가 더 필요 |
| 502/timeout인데 Pod는 Running, 뭘 먼저 보나? | logs 말고 endpoint·readiness 먼저 (traffic routing 증거) |
| requests vs limits? | requests=배치(scheduling) 기준, limits=상한(OOMKilled/throttling) |
| readiness vs liveness vs startup? | readiness=traffic 받을 준비, liveness=멈춘 process 재시작, startup=느린 시작 보호 |
| metrics-server vs Prometheus? | metrics-server=`kubectl top`/HPA용 실시간 사용량, Prometheus=시계열 관찰·대시보드 |

## notes

### Evidence Note
```markdown
# W4D1S1 운영 가능한 workload 기준
- Running과 Ready의 차이:
- 운영 가능한 workload에 필요한 기준 3가지:
- 오늘 반드시 남길 evidence:
- 내가 가장 자주 놓칠 것 같은 확인 명령:
```

### apply 순서 — 최초 구축은 유연, 운영 중엔 의존성 순서
권장 순서: **namespace → configmap → secret → deployment → service**

**① namespace는 무조건 먼저 (hard)**
- 나머지가 전부 namespace 안에 들어감 → 없으면 `namespaces "week4" not found`로 **즉시 거부**. 수렴이 아니라 아예 안 만들어짐.

**② namespace 말고는 최초엔 순서 안 지켜도 됨 (선언적 = 결국 수렴)**
- desired state를 선언하면 controller가 계속 reconcile. 의존 대상이 없으면 **에러로 기다리다 생기면 자동 회복**.

| 순서 어김 | 무슨 일 | 회복 |
|---|---|---|
| deployment를 config/secret보다 먼저 | Pod `CreateContainerConfigError`로 대기 | configmap 생기면 자동 정상화 |
| service를 deployment보다 먼저 | endpoint `<none>` | Pod 뜨면 endpoint 자동 채워짐 |

→ 다 적용해두면 순서 무관하게 같은 최종 상태로 수렴.

**③ 운영 중엔 순서 지키는 게 좋다 (왜)**
- 최초 구축은 빈 방이라 잠깐 에러 떠도 아무도 안 봄. 운영 중엔 사용자·모니터링이 보고 있어 **수렴 과정의 에러 = 실제 문제**.

| 운영 중 순서 어김 | 결과 |
|---|---|
| config 없이 deployment 먼저 | `CreateContainerConfigError`/CrashLoop → RESTARTS 증가, 알람 |
| 새 config 키 참조 deployment를 키 만들기 전 배포 | 새 Pod 실패 → rollout 멈춤/롤백 → 다운타임 위험 |
| service selector 바꾼 뒤 Pod label 늦게 맞춤 | endpoint 잠깐 빔 → 사용자 502 |

```text
최초 구축: 빈 방 → 잠깐 에러는 아무도 안 봄 → 수렴만 되면 OK
운영 중  : 사용자/모니터링이 봄 → 수렴 과정 에러 = 알람·재시작·다운타임
```

- 그래서 **의존성 있는 것(config/secret)을 소비자(deployment)보다 먼저** → transient 실패를 안 만든다.
- **deployment ↔ service 사이는 유연** (service는 Pod 생기면 endpoint 자동 갱신).
- 실무 도구가 이 순서를 자동 보장: **Helm hook/weight, Argo CD sync wave, kustomize 정렬** (Week4).

> 한 줄: **선언적이라 최종 상태는 순서와 무관하게 수렴하지만, 운영 중엔 수렴 과정의 transient 실패를 피하려 의존성 순서(config/secret→deployment)를 지킨다. namespace만 항상 hard로 먼저.**

### "실행"과 "운영"의 경계 (Week3 → Week4 다리)
- Week3 = **실행**의 기준: Pod 뜨나 / Deployment replica 맞추나 / Service 접근되나.
- Week4 Day1 = **운영**의 기준: traffic 받아도 되나(readiness) / 회복되나(liveness) / 자원 기준 있나(requests·limits) / 사용량 보이나(metrics).
- 같은 Deployment manifest에 **판단 기준 필드가 추가**되는 게 이번 주의 핵심 변화.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
