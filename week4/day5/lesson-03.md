# 3교시: Argo CD Application 생성

```bash
# 실습 환경 변수
export ARGONS=argocd
export NS=week4-gitops
export LAB=cloud-native-devops-2026/week4/day5/labs
export REPO=https://github.com/niceguy61/kdt_devops_lecture_2026_rev2.git
export APPFILE=/private/tmp/w4d5-application.yaml
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① `cat $LAB/argocd/application-template.yaml` | source(repoURL/targetRevision/path) + destination(server/namespace) + `CreateNamespace=true` 구조 확인 |
| ② `find $LAB/gitops-app -type f \| sort` | `namespace.yaml`, `configmap.yaml`, `deployment.yaml`, `service.yaml` 4개 |
| ③ template 복사 후 repoURL/path를 공개 repo 기준으로 수정 → `$APPFILE` | repoURL=`$REPO`, targetRevision=`main`, path=`week4/day5/labs/gitops-app` |
| ④ `kubectl apply -f $APPFILE` | `application.argoproj.io/w4d5-gitops-app created` |
| ⑤ `kubectl -n $ARGONS patch application w4d5-gitops-app --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}'` | 수동 sync 트리거 (CLI 없이 sync operation 주입) |
| ⑥ `kubectl -n $ARGONS get application w4d5-gitops-app` | `SYNC STATUS: Synced` / `HEALTH STATUS: Healthy` |
| ⑦ `kubectl -n $NS get deploy,svc,pod,cm` | `gitops-web 1/1`, `svc/gitops-web ClusterIP 80`, `pod ...Running`, `cm/gitops-web-content` 생성됨 |
| ⑧ `kubectl -n $NS run curltest --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- -s http://gitops-web.week4-gitops.svc.cluster.local/` | `<h1>W4D5 GitOps App</h1>` / `version: v1` 응답 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Application이 정의하는 것은? | 어느 Git repo의 어느 path를 어느 cluster/namespace에 반영할지 (repoURL+targetRevision+path → destination) |
| `server: https://kubernetes.default.svc`의 의미는? | cluster 내부에서 API server를 가리키는 기본 Service DNS. controller가 이 주소로 API 호출 |
| destination `namespace`는 HTTP 통신 대상인가? | 아니오. object를 만들 destination namespace. sync는 통신이 아니라 API를 통한 object 생성/수정 |
| `CreateNamespace=true`가 하는 일은? | Git에 namespace가 없어도 sync 시 destination namespace를 자동 생성 |
| Synced와 Healthy 차이는? | Synced=Git과 cluster object 일치, Healthy=runtime(Pod) 정상. 둘은 별개 |

## notes

### Application이란
"어느 Git repo의 어느 path를 어느 cluster/namespace에 반영할 것인가"를 정의하는 GitOps 배포 단위.

```text
repoURL + targetRevision + path
  → destination cluster + namespace
  → sync
```

| 값 | 의미 |
|---|---|
| `repoURL` / `path` | 어떤 manifest를 desired state로 볼 것인가 |
| `targetRevision` | 어느 revision(branch/tag/commit) |
| `server` | 어느 Kubernetes cluster API에 반영할 것인가 |
| `namespace` | 그 cluster의 어느 namespace에 리소스를 만들 것인가 |
| Argo CD ServiceAccount | 이 동작을 수행할 권한의 주체 |

### `kubernetes.default.svc`의 의미
destination server 기본값. cluster 내부에서 API server를 가리키는 Service DNS다.

```text
argocd-application-controller
  → kubernetes.default.svc → API server → RBAC check → week4-gitops namespace
```

여기서 `namespace: week4-gitops`는 HTTP 통신 대상이 아니라 **object를 만들 destination namespace**. sync는 "Service끼리 통신"이 아니라 "controller가 API server를 통해 object를 생성/수정"하는 흐름.

### sync할 app 구성
| 파일 | 역할 |
|---|---|
| `namespace.yaml` | 배포 namespace(week4-gitops) |
| `configmap.yaml` | nginx content(index.html, version v1) |
| `deployment.yaml` | web workload(nginx, replicas 1) |
| `service.yaml` | ClusterIP Service |

### sync 상태 읽기 (두 축)
| 상태 | 의미 |
|---|---|
| Synced | Git과 cluster object가 일치 |
| OutOfSync | Git과 cluster object가 다름 |
| Healthy | runtime 상태 정상 |
| Progressing | rollout/health 진행 중 |
| Degraded | workload 상태 이상 |
| Missing | Git엔 있는데 cluster에 없음 |

**Synced ≠ Healthy**: Git과 일치해도 Pod가 죽으면 Healthy가 아니다.

### Application 실패 원인
| 증상 | 원인 후보 |
|---|---|
| repo fetch 실패 | repoURL 오타, private repo credential 없음 |
| path 없음 | `path` 오타 |
| sync denied | RBAC 또는 Kyverno admission deny |
| namespace 없음 | CreateNamespace 옵션 누락 |
| unhealthy | Deployment/Pod runtime 문제 |

### 한 줄 요약
Argo CD Application은 **Git path와 Kubernetes destination을 연결하는 GitOps 배포 단위**다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| apply 직후 `get application`의 SYNC/HEALTH 컬럼이 빈칸 | repo fetch+render 진행 중이라 status 미기록. 20~30초 후 재조회하면 Synced/Healthy. controller 로그 `Reconciliation completed`로 진행 확인 |

