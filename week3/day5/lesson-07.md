# 7교시: Rollout과 내부 통신 검증

## 핵심 정리

### Rollout이 필요한 이유 — image 변경 = 배포
- 운영에선 **image tag 변경이 곧 배포.** Compose는 `image` 바꾸고 `up` 다시였지만, k8s Deployment는 **Pod template 변경을 rollout으로 관리**한다.
```text
Deployment template image 변경
  → 새 ReplicaSet 생성 → 새 Pod 생성 → Ready 확인 → 이전 Pod 감소
```
- 즉 image 교체가 **revision·ReplicaSet·상태확인·undo가 있는 배포 흐름**이 됨.

### 현재 상태 확인 (명령)
```bash
export NS=week3
kubectl -n "$NS" get deployment hello-web
kubectl -n "$NS" rollout history deployment/hello-web
kubectl -n "$NS" get deployment hello-web -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

### 정상 image 변경 (명령)
```bash
kubectl -n "$NS" set image deployment/hello-web nginx=nginx:1.27-alpine
kubectl -n "$NS" rollout status deployment/hello-web
kubectl -n "$NS" get deploy,rs,pod -l app=hello-web
kubectl -n "$NS" rollout history deployment/hello-web
```
- 성공 기준: `successfully rolled out`, **READY 2/2 복귀**, **새 ReplicaSet 생성**.
- `set image deployment/hello-web nginx=...` → `nginx`는 **container 이름**(manifest의 `containers[].name`), 그 image를 바꾼다.

Service 통신 재확인:
```bash
kubectl -n "$NS" run curlbox-rollout --rm -it --image=curlimages/curl:8.8.0 --restart=Never -- \
  curl -sI http://hello-web
```

### ⚠️ 실패 image 변경 — 존재하지 않는 tag로 (명령)
```bash
kubectl -n "$NS" set image deployment/hello-web nginx=nginx:not-a-real-tag
kubectl -n "$NS" rollout status deployment/hello-web --timeout=20s || true
kubectl -n "$NS" get pods -l app=hello-web
kubectl -n "$NS" describe deployment hello-web
```

| 증거 | 의미 |
|---|---|
| rollout timeout | 새 revision이 성공 못 함 |
| 새 Pod `ImagePullBackOff` | image tag 오류 (3교시 장애1과 동일) |
| 기존 Pod 일부 Running | rolling update 중 기존 replica가 남아 있음 |
| Deployment condition | Progressing/Available 상태 확인 |

- ⭐ **실패 rollout ≠ 즉시 전체 중단.** rolling update라 **기존 Pod가 남아 Service는 여전히 응답**할 수 있다. 하지만 배포는 실패 상태 → **반드시 복구**.
- `--timeout=20s || true` = 실패 rollout은 영원히 안 끝나므로 20초만 기다리고 넘어감. (3교시 `|| true`와 같은 맥락)

### undo로 복구 (명령)
```bash
kubectl -n "$NS" rollout undo deployment/hello-web
kubectl -n "$NS" rollout status deployment/hello-web
kubectl -n "$NS" get deploy,rs,pod -l app=hello-web
kubectl -n "$NS" rollout history deployment/hello-web
```
- `undo`는 직전 revision의 ReplicaSet으로 되돌림 → 새(실패) ReplicaSet 0, 이전(정상) ReplicaSet 복귀.

복구 후 Service 확인:
```bash
kubectl -n "$NS" run curlbox-after-undo --rm -it --image=curlimages/curl:8.8.0 --restart=Never -- \
  curl -sI http://hello-web
```

### image tag 운영 기준 (W3D3 tag와 연결)
| 나쁜 기준 | 문제 |
|---|---|
| 항상 `latest` | 무엇이 배포됐는지 추적 어려움 |
| commit과 image tag 불일치 | 장애 시 원인 commit 추적 어려움 |
| 수동 변경만 기록 | rollback 근거 부족 |

| 권장 기준 | 설명 |
|---|---|
| app version ↔ image tag 연결 | 앱 version과 배포 image를 맞춤 |
| Git SHA / release tag 기록 | 어떤 소스에서 나온 image인지 추적 |
| rollout history/evidence 저장 | 실패 시 되돌릴 기준 확보 |

### Argo CD와의 연결
- 오늘은 `kubectl set image`로 **live object를 직접** 바꿈 (= drift, 5교시 연결).
- Week4에선 **Git의 manifest가 기준**, Argo CD가 cluster live와 Git을 비교/sync.
```text
Day5: kubectl로 rollout 흐름 이해
Week4: Argo CD로 GitOps sync/drift 이해
```

### 한 줄 요약
> **Rollout은 image 변경을 단순 교체가 아니라 revision·ReplicaSet·상태 확인·undo가 있는 배포 흐름으로 만든다.**

## 실습 확인 기록

### ① 현재 상태 — rollout 전 베이스라인
```text
$ kubectl -n week3 get deployment hello-web
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
hello-web   2/2     2            2           145m

$ kubectl -n week3 rollout history deployment/hello-web
deployment.apps/hello-web
REVISION  CHANGE-CAUSE
1         <none>                ← 아직 변경 없음, revision 1 하나뿐

$ kubectl -n week3 get deployment hello-web -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
nginx:1.27                      ← 현재 image (이걸 바꿔서 rollout 만들 것)
```
- 읽는 포인트:
  - **READY 2/2** 정상 베이스라인. image `nginx:1.27`, **revision 1** 하나뿐.
  - **CHANGE-CAUSE `<none>`** = 변경 사유 미기록. (`--record`는 deprecated, 운영에선 manifest의 `kubernetes.io/change-cause` annotation으로 남김)
  - 여기서 image를 바꾸면 **revision 2**가 생기며 rollout 시작 → ②에서 비교.

### ② 정상 image 변경 — 새 ReplicaSet으로 교체
```text
$ kubectl -n week3 set image deployment/hello-web nginx=nginx:1.27-alpine
deployment.apps/hello-web image updated

$ kubectl -n week3 rollout status deployment/hello-web
deployment "hello-web" successfully rolled out      ← 새 Pod 2개 다 Ready까지 기다렸다 성공

$ kubectl -n week3 get deploy,rs,pod -l app=hello-web
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hello-web   2/2     2            2           148m

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/hello-web-54f9d49f5b   2         2         2       69s      ← 새 RS (새 해시), 0→2로 채워짐
replicaset.apps/hello-web-74d95c87c8   0         0         0       148m     ← 옛 RS (이전 해시), 2→0으로 비워짐

NAME                             READY   STATUS    RESTARTS   AGE
pod/hello-web-54f9d49f5b-gvxnf   1/1     Running   0          69s          ← Pod 이름의 해시가 새 RS(54f9d49f5b)
pod/hello-web-54f9d49f5b-p7gdf   1/1     Running   0          64s

$ kubectl -n week3 rollout history deployment/hello-web
REVISION  CHANGE-CAUSE
1         <none>
2         <none>                ← revision 2 추가 (이전 1은 undo용으로 남음)
```
- 읽는 포인트:
  - **RS가 2개**로 보임: 새 `54f9d49f5b`(DESIRED 2)와 옛 `74d95c87c8`(DESIRED 0). rollout = **새 RS를 0→2로 늘리고 옛 RS를 2→0으로 줄이는** 교체.
  - **Pod 이름의 해시가 새 RS 해시(`54f9d49f5b`)** → 새 template의 Pod로 전부 바뀜. (①의 `74d95c87c8`에서 변경)
  - **옛 RS가 0으로 남아있는 이유** = `undo`로 되돌릴 수 있게 보존(`revisionHistoryLimit`만큼). 삭제가 아니라 비워둠.
  - **revision 2 추가** → `rollout history`에 1·2 둘 다. revision 1이 남아 있어야 undo 가능.

**정상 rollout 후 Service 통신 재확인**
```text
$ kubectl -n week3 run curlbox-rollout --rm -it --image=curlimages/curl:8.8.0 --restart=Never -- curl -sI http://hello-web
HTTP/1.1 200 OK
Server: nginx/1.27.5
```
- Pod가 새 RS로 통째로 바뀌었어도 **Service는 그대로 200** → Service는 endpoint(Ready Pod)를 실시간으로 따라가므로 rollout 중에도 접근점이 안정적. (6교시 "Pod IP를 숨긴다"의 실증)
- `Server: nginx/1.27.5` = `1.27-alpine`도 nginx 1.27.5 → image variant만 바뀌고 버전은 동일.

### ③ ⚠️ 실패 rollout — 새 Pod는 ImagePull 실패, 기존 Pod는 살아있음
```text
$ kubectl -n week3 set image deployment/hello-web nginx=nginx:not-a-real-tag
deployment.apps/hello-web image updated

$ kubectl -n week3 rollout status deployment/hello-web --timeout=20s || true
Waiting for deployment "hello-web" rollout to finish: 1 out of 2 new replicas have been updated...
error: timed out waiting for the condition          ← 새 revision이 Ready 안 돼서 timeout

$ kubectl -n week3 get pods -l app=hello-web
NAME                         READY   STATUS         RESTARTS   AGE
hello-web-54f9d49f5b-gvxnf   1/1     Running        0          6m49s    ← 기존(alpine) Pod 그대로 살아있음
hello-web-54f9d49f5b-p7gdf   1/1     Running        0          6m44s    ← 기존(alpine) Pod 그대로 살아있음
hello-web-6d64b4d899-wlw55   0/1     ErrImagePull   0          39s      ← 새(bad-tag) Pod만 실패
```
- `describe deployment` 핵심:
```text
Annotations:  deployment.kubernetes.io/revision: 3
Replicas:     2 desired | 1 updated | 3 total | 2 available | 1 unavailable
Conditions:
  Available    True    MinimumReplicasAvailable     ← ⭐ 아직 사용 가능 (기존 Pod 덕분)
  Progressing  True    ReplicaSetUpdated            ← 진행 중이지만 새 RS가 못 뜸
OldReplicaSets:  hello-web-74d95c87c8 (0/0), hello-web-54f9d49f5b (2/2 replicas created)   ← 직전 정상 RS가 2개 유지
NewReplicaSet:   hello-web-6d64b4d899 (1/1 replicas created)                               ← 새 RS는 1개 시도, 실패
```
- 읽는 포인트:
  - ⭐ **`2 available`로 서비스는 살아있음.** rolling update + `maxUnavailable 25%`라 **기존 정상 Pod(54f9d49f5b 2개)를 안 죽이고**, 새 Pod가 Ready 될 때까지 기다리는 중. → 새 image가 깨져도 **즉시 전체 중단은 아님.**
  - **새 RS(`6d64b4d899`)는 1개만 시도하다 `ErrImagePull`로 멈춤** → `1 updated`, `1 unavailable`. maxSurge 만큼만 새로 띄우고, 그게 안 떠서 더 진행 못 함.
  - **RS가 3개**로 보임: `74d95c87c8`(0, 최초) / `54f9d49f5b`(2, 직전 정상) / `6d64b4d899`(1, 실패). revision도 **3**으로 증가.
  - **Conditions `Available=True` + `Progressing=True`** = "지금은 쓸 수 있지만 새 배포는 아직 진행/미완". `rollout status`가 timeout 난 이유 = 새 RS가 끝내 Ready가 안 돼서.
  - ⚠️ 서비스가 응답해도 **배포는 실패 상태** → 반드시 undo로 복구해야 함 (④).

### ④ undo로 복구 — 직전 정상 revision으로 되돌림
```text
$ kubectl -n week3 rollout undo deployment/hello-web
deployment.apps/hello-web rolled back

$ kubectl -n week3 rollout status deployment/hello-web
deployment "hello-web" successfully rolled out      ← 바로 성공 (되돌릴 정상 RS가 이미 떠 있어서)

$ kubectl -n week3 get deploy,rs,pod -l app=hello-web
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hello-web   2/2     2            2           157m

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/hello-web-54f9d49f5b   2         2         2       9m59s    ← 정상(alpine) RS로 복귀
replicaset.apps/hello-web-6d64b4d899   0         0         0       3m49s    ← 실패(bad-tag) RS는 0으로 빠짐
replicaset.apps/hello-web-74d95c87c8   0         0         0       157m     ← 최초 RS도 0으로 보존

NAME                             READY   STATUS    RESTARTS   AGE
pod/hello-web-54f9d49f5b-gvxnf   1/1     Running   0          9m59s        ← ErrImagePull Pod 사라지고 alpine Pod만 2개
pod/hello-web-54f9d49f5b-p7gdf   1/1     Running   0          9m54s

$ kubectl -n week3 rollout history deployment/hello-web
REVISION  CHANGE-CAUSE
1         <none>
3         <none>
4         <none>                ← undo도 "새 revision 4"로 기록됨 (revision 2가 4로 재등장)
```
- 읽는 포인트:
  - **실패 RS(`6d64b4d899`) 2→0**, **정상 RS(`54f9d49f5b`) 유지 2/2** → undo = 실패 RS를 비우고 직전 정상 RS로 desired를 되돌리는 것.
  - **`ErrImagePull` Pod(`wlw55`)가 사라짐** → 이제 alpine Pod 2개만 Running. (③의 3번째 Pod 제거)
  - **undo가 빨리 성공한 이유** = 되돌릴 정상 RS(`54f9d49f5b`)가 이미 2/2로 떠 있어서 새로 만들 게 없음. (실패 rollout이 기존 Pod를 안 죽인 덕 = ③의 안전장치)
  - ⭐ **history에서 revision 2가 사라지고 4가 생김**: undo는 "과거로 점프"가 아니라 **그 내용을 새 revision(4)으로 다시 적용**. 그래서 번호는 계속 증가(1→3→4). revision은 "시간 순서 기록"이지 되감기가 아님.

**복구 후 Service 통신 재확인**
```text
$ kubectl -n week3 run curlbox-after-undo --rm -it --image=curlimages/curl:8.8.0 --restart=Never -- curl -sI http://hello-web
HTTP/1.1 200 OK
Server: nginx/1.27.5
```
- undo 후에도 `200 OK` → 복구 완료 확인. (②의 정상 rollout 때와 같은 alpine RS라 `nginx/1.27.5` 동일)
- 사실 실패 rollout(③) 중에도 기존 Pod 덕에 200이 나왔으므로, **"200이 나온다"만으로 배포 성공을 판단하면 안 된다.** 배포 성공은 `rollout status` + `get rs`(새 RS가 desired만큼 Ready)로 확인. → 통신 검증과 배포 검증은 별개.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Deployment image를 바꾸면 무슨 일이? | 새 ReplicaSet 생성 → 새 Pod Ready → 이전 Pod 감소 (rollout) |
| `set image ... nginx=...`의 `nginx`는? | container 이름(manifest의 containers[].name). 그 container의 image를 교체 |
| 실패 rollout이면 서비스가 즉시 죽나? | 아닐 수 있음. rolling update라 기존 Pod가 남아 Service 응답 가능. 단 배포는 실패 → 복구 필요 |
| 실패 rollout의 대표 증거는? | rollout timeout + 새 Pod ImagePullBackOff + 기존 Pod 일부 Running |
| `rollout undo`가 하는 일은? | 직전 revision의 ReplicaSet으로 되돌림 (실패 RS 0, 정상 RS 복귀) |
| `latest` tag가 나쁜 이유는? | 무엇이 배포됐는지 추적 불가. app version/Git SHA와 image tag를 맞춰야 |

## notes

### Evidence Note
```markdown
# W3D5S7 Rollout
- initial image:
- changed image:
- successful rollout evidence:
- failed image:
- failure symptom:
- undo result:
- Service response after undo:
- image tag 운영 기준:
```

### rollout은 ReplicaSet 교체로 이뤄진다 (4·5교시 연결)
- image를 바꾸면 **새 pod-template-hash → 새 ReplicaSet** 생성. Deployment가 새 RS를 0→2로 늘리고 옛 RS를 2→0으로 줄임.
- 그래서 rollout 중엔 `get rs`에 **RS가 2개**(old/new) 보일 수 있음. `undo`는 이 방향을 거꾸로 돌리는 것.
- revision 이력은 `rollout history`로 남음 → 되돌릴 기준.

### 실패 rollout이 "한 번 걸러지는" 이유 = rolling update 안전장치
- 실패 image를 넣어도 서비스가 안 죽는 건 운이 아니라 **설계된 안전장치**다.
```text
maxUnavailable: 25%  → 정상 Pod를 한꺼번에 다 죽이지 마라
maxSurge: 25%        → 새 Pod를 조금씩만 추가해봐라
```
- 흐름: 새 Pod를 maxSurge만큼만 띄움 → **Ready가 돼야** 기존 Pod를 죽이기 시작 → 새 Pod가 `ErrImagePull`로 영영 Ready 안 됨 → **기존 정상 Pod를 안 죽임** → 서비스 유지(`2 available`), 배포만 멈춤.
- 즉 **"Ready 안 되면 다음 단계로 안 넘어간다"**가 핵심. 나쁜 배포를 한 번 걸러준다.

⚠️ 단, **항상 살려주는 건 아니다.** "새 Pod가 Ready 안 되는" 실수에만 통함:

| 실수 유형 | 보호? | 이유 |
|---|---|---|
| 없는 tag(`ErrImagePull`) / `CrashLoopBackOff` / readiness 실패 | ✅ | 새 Pod가 Ready 안 됨 → 기존 Pod 유지 |
| image는 정상인데 앱 버그(500 등) | ❌ | Ready 통과 → 기존 Pod 다 교체 → 전체 깨짐 |
| readiness probe를 안 걸어둠 | ⚠️ | "뜨기만 하면 Ready"로 봐서 깨진 앱도 교체될 수 있음 |

- → **readiness probe를 제대로 거는 게 이 안전장치의 전제.** probe가 "진짜 정상"을 판별해야 rolling update가 나쁜 배포를 거른다.
- 그리고 서비스가 살아있어도 **배포는 실패 상태**(revision 3, Progressing 미완) → 방치 금지, **`undo`로 복구 필수**.

> 한 줄: **rolling update + readiness가 "새 Pod Ready 될 때까지 기존 Pod를 안 죽여서" 나쁜 배포를 한 번 걸러준다. 단 Ready 통과하는 버그는 못 막으니 probe + undo가 필요.**

### set image(live 변경) vs manifest(desired) — 또 drift
- `set image`는 5교시 `scale`처럼 **live object 직접 변경** = manifest와 어긋남(drift).
- 수업에선 rollout 흐름을 빠르게 보려고 씀. 운영 기준은 **Git manifest 수정 → Argo CD sync** (Week4).

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
