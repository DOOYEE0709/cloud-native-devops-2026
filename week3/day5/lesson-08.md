# 8교시: 구름 EXP 배움일기

## 핵심 정리

### 오늘은 외운 날이 아니라 "손으로 확인한" 날
```text
context 확인
  → namespace 생성
  → Pod 실행
  → Pod 장애 읽기 (ImagePullBackOff / CrashLoopBackOff)
  → Deployment로 replica 유지 + self-healing
  → Service로 내부 접근 (selector → endpoint → DNS)
  → rollout 실패와 undo
```
- object를 많이 외운 게 아니라, **적용한 상태가 cluster에서 어떻게 변하는지 kubectl 증거로 읽은 것**이 오늘의 핵심. (1교시 한 줄 요약과 수미상관)

### Day5 한눈에 — 교시별 핵심 1줄
| 교시 | 핵심 | 대표 증거 |
|---|---|---|
| 1 | kubectl 운영 루프 (apply→get→describe→logs) | `current-context`, `get nodes` |
| 2 | Pod = 최소 workload 단위 | `describe pod`의 Events·containerd |
| 3 | 장애 읽기: ImagePull≠Crash | `describe`(ErrImagePull) / `logs`(crash) |
| 4 | Deployment = self-healing/replica 유지 | `delete pod` → 재생성, owner=RS |
| 5 | manifest 해부 (replicas·selector·template) | `get -o yaml`의 spec vs status |
| 6 | Service = 안정적 내부 접근점 | endpoint, DNS, selector 장애 |
| 7 | rollout = revision·RS 교체·undo | 실패 rollout + `rollout undo` |

### evidence를 남기는 기준 — "무엇을 봤나 + 그게 무슨 뜻인가"
| 항목 | 남길 evidence | 해석 문장 |
|---|---|---|
| Context | `kubectl config current-context` | 어느 cluster에 명령 보내는지 확인 |
| Namespace | `kubectl get ns week3` | object를 기본 namespace와 분리 |
| Pod | `kubectl -n week3 get pods -o wide` | 상태·node 배치·Pod IP 확인 |
| 장애 Pod | `kubectl -n week3 describe pod ...` | event에서 pull 실패/restart 원인 |
| Deployment | `kubectl -n week3 get deploy,rs,pod` | RS와 Pod 수 맞추는 것 확인 |
| Service | `kubectl -n week3 get svc,endpoints hello-web` | selector가 Ready Pod endpoint로 연결 |
| Rollout | `kubectl -n week3 rollout status deploy/hello-web` | 새 version 배포 성공 여부 |
| Undo | `kubectl -n week3 rollout undo deploy/hello-web` | 실패 배포를 이전 revision으로 복구 |

- ⚠️ k9s 화면 캡처만 ❌ → **재현 가능한 명령 출력 + 해석**을 함께 남긴다. (6교시 원칙)

### ⭐ 오늘의 성공 기준
> **모든 명령을 외우는 게 아니라, 실패했을 때 `get → describe → logs/events → 복구` 순서로 움직일 수 있으면 성공.**

### 한 줄 요약
> **Day5는 Pod·Deployment·Service·rollout을 "느낌"이 아니라 명령 출력·event·log로 설명할 수 있게 된 날이다.**

## 실습 확인 기록

### Day5 evidence 종합 (lesson별 실제 출력 위치)
| 개념 | 핵심 증거 | 어디서 봤나 |
|---|---|---|
| 첫 Pod | `1/1 Running`, describe Events, exec→logs 200 | lesson-02 ①~④ |
| ImagePullBackOff | `describe`에 ErrImagePull, **Restart 0**(뜬 적 없음) | lesson-03 ①② |
| CrashLoopBackOff | `logs` crash, RESTARTS 증가, 3국면 전이 | lesson-03 ③~⑥ |
| Deployment/self-healing | scale 2↔3, delete→재생성, owner=RS | lesson-04 ①~⑤ |
| manifest | scale 전파, jsonpath image, `-o yaml` spec/status | lesson-05 ①~⑤ |
| Service | ClusterIP·endpoint, DNS 성공/실패, **selector 장애** | lesson-06 ①~⑤ |
| rollout | 정상→실패(ImagePull)→undo, revision 1·3·4 | lesson-07 ①~④ |

- 위 표는 "오늘 무엇을 직접 증거로 확인했는지"의 인덱스. 각 lesson 실습 확인 기록에 실제 출력이 번호로 정리돼 있음.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| `kubectl`은 어디에 요청을 보내는가? | API Server |
| 직접 Pod vs Deployment Pod, 삭제 시 차이는? | controller 유무 — Deployment Pod는 ReplicaSet이 재생성(self-healing) |
| `ImagePullBackOff`에서 logs가 없을 수 있는 이유는? | container가 시작조차 못 해서 (Restart 0) |
| Service endpoint가 비면 먼저 볼 것은? | selector와 Pod label 일치 여부 |
| rollout 실패 후 되돌린 명령은? | `kubectl rollout undo` |
| Week4 add-on 설치는 어떤 도구로 통일? | Helm |
| 실패 rollout인데 서비스가 응답한 이유는? | rolling update가 기존 Ready Pod를 안 죽여서 (배포는 실패 상태) |

## notes

### 오늘 관통한 반복 주제
- **desired state vs actual**: manifest(원함) ↔ live(실제). `scale`/`set image`로 어긋남 = drift → Argo CD(Week4).
- **소유 사슬**: Pod ← ReplicaSet ← Deployment. self-healing·rollout·undo가 다 이 구조 위에서 동작.
- **장애는 "어디서 멈췄나"**: image pull / process start / scheduling / routing — STATUS로 증상, describe·logs로 원인.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
