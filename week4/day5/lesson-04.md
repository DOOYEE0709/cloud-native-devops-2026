# 4교시: Drift와 Sync

```bash
# 실습 환경 변수
export ARGONS=argocd
export NS=week4-gitops
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① `kubectl -n $NS scale deploy/gitops-web --replicas=2` | `deployment.apps/gitops-web scaled` (cluster를 직접 변경 = drift 유발) |
| ② `kubectl -n $NS get deploy gitops-web` | `1/2` → `2/2` (Git은 여전히 replicas 1) |
| ③ `kubectl -n $ARGONS annotate application w4d5-gitops-app argocd.argoproj.io/refresh=hard --overwrite` | drift 재비교 트리거 |
| ④ `kubectl -n $ARGONS get application w4d5-gitops-app` | `SYNC STATUS: OutOfSync` / `HEALTH: Healthy` (drift 감지됐지만 Pod는 살아있음) |
| ⑤ resource별 status 조회 | `Deployment gitops-web → OutOfSync`, 나머지(Namespace/ConfigMap/Service) → `Synced` |
| ⑥ `kubectl -n $ARGONS patch application w4d5-gitops-app --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}'` | Git 기준으로 재sync |
| ⑦ `kubectl -n $ARGONS get application w4d5-gitops-app` | `SYNC STATUS: Synced` / `HEALTH: Healthy` (복구) |
| ⑧ `kubectl -n $NS get deploy gitops-web` | `1/1` — Git 기준(replicas 1)으로 되돌아옴 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| drift란? | Git 선언 상태 ≠ cluster 실제 object. 여기선 Git=1, Cluster=2 → OutOfSync |
| drift는 무조건 나쁜가? | 아니오. 장애 대응 중 임시 scale out 같은 의도된 drift도 있음. 단, 끝나면 Git 반영 또는 Git 기준 복구 |
| OutOfSync인데 Healthy인 이유는? | sync축(Git 일치 여부)과 health축(runtime 정상)은 별개. replicas 2도 Pod는 정상 |
| Self-heal을 함부로 켜면 안 되는 이유는? | 장애 대응 중 임시 조치까지 즉시 되돌려버림 → incident 임시조치 기준 먼저 정의 필요 |
| Prune 위험은? | Git path에서 실수로 빠진 리소스나 stateful 리소스를 승인 없이 삭제할 수 있음 |
| GitOps에서 `kubectl rollout undo`만 하면? | Git과 cluster가 다시 달라짐(새 drift). 장기 복구는 Git에 반영해야 함 |

## notes

### Drift란
Git에 선언된 상태와 cluster 실제 object가 달라진 상태.

```text
Git: replicas 1
Cluster: replicas 2
Argo CD: OutOfSync
```

drift가 무조건 나쁜 건 아니다. 장애 대응 중 임시 scale out 같은 **의도된 drift**도 있다. 단, 임시 조치가 끝나면 Git에 반영하거나 Git 기준으로 되돌려야 한다.

### Sync 방식 4가지
| 방식 | 의미 |
|---|---|
| Manual Sync | 사람이 버튼/CLI로 sync |
| Auto Sync | Git 변경을 자동 반영 |
| Self-heal | cluster drift를 자동 복구 |
| Prune | Git에서 삭제된 리소스를 cluster에서도 삭제 |

수업은 manual sync로 시작. 자동화는 편하지만 **정책·승인 기준이 먼저** 필요하다.

### Prune 주의
| 장점 | 위험 |
|---|---|
| 유령 리소스 제거 | 실수로 Git path에서 빠진 리소스 삭제 |
| drift 감소 | stateful 리소스 삭제 위험 |
| 운영 정리 | 승인 없는 삭제 사고 가능 |

처음엔 바로 켜지 말고 어떤 리소스가 삭제될지 먼저 확인.

### Self-heal 주의
```text
좋은 경우:  수동 replicas 변경 → Argo CD가 Git 기준으로 복구
주의 경우:  장애 대응 중 임시 scale out → self-heal이 바로 되돌림
```
켜기 전에 incident 임시 조치 기준을 정해야 한다.

### Rollback 기준
| 방법 | 기준 |
|---|---|
| Git revert | 잘못된 manifest commit 되돌림 |
| Argo CD history rollback | 이전 synced revision으로 이동 |
| image tag rollback | manifest의 image tag를 이전 버전으로 |
| Kubernetes rollout undo | GitOps와 충돌할 수 있어 주의 |

GitOps에서 `kubectl rollout undo`만 하면 Git과 cluster가 다시 달라진다(새 drift). 장기 복구는 Git에 반영해야 한다.

### Kyverno와 sync failure
```text
Application OutOfSync → sync failed → admission webhook denied → policy/rule/message 확인
```
policy 위반 manifest는 sync에서 실패한다. Argo CD를 의심하기 전에 policy+manifest를 같이 본다. (이번 drift 실습은 replicas 변경이라 policy에 안 걸림.)

### 한 줄 요약
GitOps에서 drift는 Git과 cluster가 다르다는 **신호**이며, sync는 **어느 쪽을 기준으로 복구할지 결정하는 운영 행위**다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| scale 직후 UI/CLI가 계속 Synced로 보임 | Argo CD 재비교 주기 전이라 그럴 수 있음. `annotate ... refresh=hard`로 즉시 재비교하면 OutOfSync 반영 |

