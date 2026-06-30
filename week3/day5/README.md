# Week 3 Day 5 — 첫 앱 실행: Pod → Deployment → Service → Rollout

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Day4 요약 + kubectl 운영 루프 | manifest→apply→API Server→controller/scheduler/kubelet→get/describe/logs. context 먼저 확인. namespace=실습 울타리. 실패는 "어디서 멈췄나"로 읽기 |
| 2교시 | 첫 Pod 실행 | Pod manifest 4대 필드(apiVersion/kind/metadata/spec). containerPort≠`-p`. describe Events·containerd 확인. exec→logs로 응답 증거. 직접 Pod의 한계 |
| 3교시 | Pod 장애 읽기 | ImagePullBackOff(`describe`, Restart 0=뜬 적 없음) ≠ CrashLoopBackOff(`logs`+`--previous`, RESTARTS 증가). k9s는 보조 도구. STATUS는 증상, 원인은 event·log |
| 4교시 | Deployment가 필요한 이유 | desired state·self-healing(Pod 삭제→재생성)·replica 유지. Deployment replica vs ReplicaSet replica(둘 다 node별 아님). 소유 사슬 Pod←RS←Deployment. 스케줄러 분산 |
| 5교시 | Deployment Manifest 해부 | replicas·selector·template이 핵심. selector↔template label이 소유 관계를 만듦. `scale`은 live 변경=drift. spec(desired) vs status(actual) |
| 6교시 | Service와 내부 DNS | Service=Pod IP를 숨기는 안정적 접근점(네트워크 규칙/가상 IP). selector→endpoint, CoreDNS 이름 해석. DNS 성공≠통신 성공. selector 장애로 endpoint 빔 |
| 7교시 | Rollout과 내부 통신 검증 | image 변경=새 ReplicaSet 교체. 정상→실패(ImagePull)→`undo` 복구. rolling update가 기존 Pod 유지로 나쁜 배포 한 번 거름. revision은 증가 기록 |
| 8교시 | 구름 EXP 배움일기 | Day5 종합·회고. "외운 날이 아니라 손으로 확인한 날". evidence 남기는 기준. 성공=`get→describe→logs→복구`로 움직이기. Week4 예고 |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 핵심 정리·실습 확인 기록(실제 출력)·확인 질문·notes·Blocker Log |
| `labs/k8s-first-app/namespace.yaml` | `week3` namespace |
| `labs/k8s-first-app/pod-hello.yaml` | 첫 Pod(nginx) |
| `labs/k8s-first-app/pod-bad-image.yaml` | ImagePullBackOff 재현(없는 tag) |
| `labs/k8s-first-app/pod-crashloop.yaml` | CrashLoopBackOff 재현(busybox `exit 1`) |
| `labs/k8s-first-app/deployment.yaml` | hello-web Deployment(replicas 2) |
| `labs/k8s-first-app/service.yaml` | hello-web Service(ClusterIP) |
| `assets/` | 교시별 강의 이미지 |

## 실습 흐름 (cluster → namespace → deployment → service)

```text
kind cluster (Day4에서 생성)
  → kubectl apply namespace.yaml      # week3 (방)
  → kubectl apply pod-hello.yaml       # 첫 Pod
  → pod-bad-image / pod-crashloop      # 장애 읽기
  → kubectl apply deployment.yaml      # replica·self-healing
  → kubectl apply service.yaml         # 내부 접근점
  → set image → rollout → undo         # 배포·복구
```

## 관통하는 반복 주제
- **desired state vs actual**: manifest(원함) ↔ live(실제). `scale`·`set image`가 만드는 어긋남 = drift → Argo CD(Week4).
- **소유 사슬**: Pod ← ReplicaSet ← Deployment. self-healing·rollout·undo가 다 이 구조 위에서 동작.
- **장애는 "어디서 멈췄나"**: image pull / process start / scheduling / routing. STATUS로 증상, `describe`·`logs`로 원인.

## 핵심 한 줄
Day5는 Kubernetes object를 많이 외운 날이 아니라, kind cluster 위에 Pod → Deployment → Service → rollout을 직접 올리며 **적용한 상태가 cluster에서 어떻게 변하는지 kubectl 출력·event·log로 읽은** 날이다. 장애가 났을 때 `get → describe → logs/events → 복구` 순서로 움직일 수 있으면 Day5 완료.

## 다음 연결
Week4는 이 기본 object 위에 운영 도구를 얹는다 — Helm·metrics-server(resource), ingress-nginx(외부 노출), kube-prometheus-stack(관찰), RBAC·Kyverno(권한·정책), Argo CD(GitOps drift), Istio/Kiali(mesh).
