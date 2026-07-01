# 7교시: Metrics Server 설치와 관찰

> ⭐ metrics-server 설치·검증은 **3교시(Helm 공통 설치 루프)** 에서 이미 함 (`kubectl top node` 동작 확인). 여기서는 **왜 top이 되는지(Metrics API 경로) + 실제 관찰 + Prometheus와의 차이**에 집중.

## 핵심 정리

### metrics-server의 위치 — 실시간 resource metric 공급원
```text
kubelet → metrics-server → metrics.k8s.io API → kubectl top / HPA
```
- ⭐ metrics-server = **"지금 CPU/memory 얼마 쓰나"** 를 제공. 장기 저장·dashboard·alert는 **아님** (그건 Prometheus/Grafana, W4D3).

### metrics-server vs Prometheus/Grafana — 목적이 다르다
| 항목 | metrics-server | Prometheus/Grafana |
|---|---|---|
| 주 목적 | **현재** resource metric | 시계열 저장·query·dashboard·alert |
| 대표 명령/화면 | `kubectl top` | PromQL, Grafana |
| 저장 기간 | 짧음(현재값) | 장기 |
| HPA | resource metric 직접 연결 | custom/external metric |
| 수업 일차 | W4D1 | W4D3 |

### kube-system에 있는데 `-n week4`가 보이는 이유
```text
kubectl top pod -n week4
  → Kubernetes API server
  → APIService: v1beta1.metrics.k8s.io
  → Service: kube-system/metrics-server
  → metrics-server
  → 각 node의 kubelet resource summary
  → 결과를 week4 namespace로 필터
```
- ⭐ week4 Pod가 metrics-server와 **직접 통신하는 게 아님.** 사용자는 API server에 요청 → API server가 **APIService(aggregation)** 로 metrics-server에 라우팅.
- "system add-on이 app namespace를 본다" = 네트워크가 뚫린 게 아니라 **API/RBAC/APIService/selector가 허용한 범위** 안 동작.

### 설치 확인 레이어 (3교시 복습)
```bash
helm list -n kube-system
kubectl -n kube-system get deploy,pod -l app.kubernetes.io/name=metrics-server
kubectl get apiservice v1beta1.metrics.k8s.io          # AVAILABLE True 필수
kubectl -n kube-system get deploy metrics-server \
  -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}'   # insecure-tls args 확인
```
- ⭐ **`APIService AVAILABLE True`가 되어야 `kubectl top`이 동작.** Pod `READY 1/1` 전이나 API 미등록이면 top 실패.

### metric 확인
```bash
kubectl top node
kubectl top pod -n week4
kubectl top pod -n week4 --containers    # Pod 안 container별 (sidecar 있을 때 중요)
```
- ⚠️ 설치 직후 30~90초는 `error: Metrics API not available`이 정상일 수 있음 (수집 대기).

### 자주 보는 문제 & 판단
| 증상 | 원인 후보 | 확인 |
|---|---|---|
| `Metrics API not available` | APIService 준비 전/실패 | `kubectl get apiservice v1beta1.metrics.k8s.io` |
| `top`이 비어 있음 | Pod 없거나 namespace 오타 | `kubectl -n week4 get pods` |
| metrics-server CrashLoop | kubelet 연결/TLS/args | `kubectl -n kube-system logs deploy/metrics-server` |
| release는 있는데 Pod 없음 | install 실패/namespace 혼동 | `helm status metrics-server -n kube-system` |

### kind/local의 x509 이슈 — `--kubelet-insecure-tls`
```text
metrics-server가 kubelet https://<node-ip>:10250/metrics/resource 를 긁음
  → kubelet 인증서에 그 IP가 SAN에 없음 → TLS 검증 실패(x509)
  → no metrics to serve → top 실패
```
- 그래서 실습 values에 **`--kubelet-insecure-tls`**(TLS 검증 우회)를 넣음. **운영 보안 기준 아님, 로컬 우회.**
- ⚠️ 같은 x509가 계속되면 **context/cluster 확인**: 엉뚱한(이전 week3) cluster에 설치했거나 그 context를 보고 있을 수 있음.

### "Helm 성공 ≠ top 동작" 레이어 분리
| 단계 | 성공해도 | 아직 실패 가능 |
|---|---|---|
| `helm upgrade --install` | 리소스 제출 | Pod readiness |
| `helm status` deployed | release 정상 | metrics API 미등록 |
| Pod Running | process 실행 | kubelet scrape 실패 |
| APIService True | API 연결 | metric 수집 대기 |

### HPA preview — 6교시 request와 연결
```text
requests 선언 → metrics-server가 사용량 제공 → HPA가 사용률 계산 → replica 조정
utilization = 현재 CPU 사용량 / requests.cpu
```
- ⭐ **request가 없으면 HPA가 사용률을 계산 못 함** → 6교시 resource와 7교시 metric은 한 묶음.

### 한 줄 요약
> **metrics-server는 kubectl top·HPA의 실시간 resource metric 공급원이고, APIService(aggregation)로 API server에 붙어 동작한다. Prometheus/Grafana와 목적이 다르다.**

## 실습 확인 기록

### ① metrics-server 동작 확인 — APIService True
```text
$ kubectl get apiservice v1beta1.metrics.k8s.io
NAME                     SERVICE                      AVAILABLE   AGE
v1beta1.metrics.k8s.io   kube-system/metrics-server   True        ...

$ kubectl -n kube-system get pod -l app.kubernetes.io/name=metrics-server
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-xxxxxxxxxx-xxxxx   1/1     Running   0          ...
```
- 읽는 포인트:
  - ⭐ **`AVAILABLE True`** = Metrics API가 cluster에 붙음 → top 동작 가능. (3교시에서 확인한 그 APIService)
  - Pod `1/1 Running` + APIService True 두 층이 다 통과해야 top이 됨.

### ② kubectl top node — node 실제 사용량
```text
$ kubectl top node
NAME                            CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
paperclip-week3-control-plane   156m         1%       1414Mi          17%
```
- 읽는 포인트:
  - ⭐ **실제 수치 출력** = metrics-server 체인이 끝까지 동작 (1교시/3교시에서 막혔던 `Metrics API not available` 해소).
  - **CPU `156m`(1%)** = 6교시 request/limit(선언값)과 달리 **지금 진짜 쓰는 양**. 선언 ≠ 사용량. cluster가 idle이라 % 낮음(정상).
  - 절대량(`156m`)은 있는데 `1%`인 이유 = node에 core가 여러 개라 전체 대비 비율이 낮음 (`156m / 총 core`).
  - node 이름 `paperclip-week3-control-plane` = **week3 kind cluster 재사용 중** (top은 정상이라 실습엔 문제없지만, cluster 혼동 주의 포인트).
  - kind는 node가 control-plane 하나뿐이라 한 줄만 나옴.

### ③ kubectl top pod — Pod/container 사용량
```text
$ kubectl top pod -n week4
NAME                           CPU(cores)   MEMORY(bytes)
runtime-api-78975fb9df-8sl6l   1m           8Mi
runtime-api-78975fb9df-n22w2   1m           8Mi

$ kubectl top pod -n week4 --containers
POD                            NAME   CPU(cores)   MEMORY(bytes)
runtime-api-78975fb9df-8sl6l   api    1m           8Mi
runtime-api-78975fb9df-n22w2   api    1m           8Mi
```
- 읽는 포인트:
  - ⭐ **CPU `1m` / MEM `8Mi`** = 실제 사용량. 6교시 선언값(request 25m/32Mi, limit 100m/64Mi)과 비교하면 **한참 여유** → 선언은 넉넉히, 실사용은 적음을 눈으로.
  - `--containers` = Pod 안 container별. 지금은 container 1개(`api`)라 Pod와 같지만, **sidecar 있으면** 어느 container가 자원을 먹는지 분리됨.
  - `-n week4`로 필터 = metrics-server는 kube-system인데 결과는 week4 Pod만 → API server가 namespace로 필터한 것.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| metrics-server의 역할? | kubelet의 CPU/memory metric을 모아 Metrics API로 제공 → kubectl top·HPA 기반 |
| metrics-server와 Prometheus 차이? | metrics=현재값(top·HPA), Prometheus=시계열 저장·query·dashboard·alert |
| kube-system인데 `-n week4`가 보이는 이유? | API server가 APIService로 metrics-server에 라우팅하고 결과를 week4로 필터. 직접 통신 아님 |
| `kubectl top`이 동작하려면? | APIService `v1beta1.metrics.k8s.io`가 AVAILABLE True + Pod READY 1/1 |
| kind에서 `--kubelet-insecure-tls`가 왜 필요? | kubelet 인증서에 node IP가 SAN에 없어 x509 실패 → TLS 검증 우회(로컬 한정) |
| top 수치와 6교시 requests/limits 관계? | top=실제 사용량, requests/limits=선언값. HPA는 사용량/request로 사용률 계산 |
| 설치 직후 top이 안 되면 바로 실패? | 아님. 30~90초 수집 대기 정상. 2~3분 지속되면 logs·apiservice 확인 |

## notes

### Evidence Note
```markdown
# W4D1S7 metrics-server
- Helm release status:
- metrics-server Pod READY:
- APIService Available:
- kubectl top node 결과:
- kubectl top pod -n week4 결과:
- 안 될 때 확인한 log 또는 message:
```

### 선언값(6교시) vs 실사용(7교시) — 한 화면에서 비교
```text
6교시: requests 25m/32Mi, limits 100m/64Mi   ← 선언 (describe / custom-columns)
7교시: 실제 1m / 8Mi                          ← 사용 (kubectl top)
```
- ⭐ request는 "예약 약속", top은 "진짜 사용량". 둘을 비교해야 **과다/과소 선언**을 판단 → 운영 조정 루프(6교시)의 입력이 top(7교시).

### Metrics API 경로 (namespace를 넘는 원리)
```text
kubectl top -n week4
  → API server → APIService(v1beta1.metrics.k8s.io) → kube-system/metrics-server → kubelet
```
- 3교시 "APIService가 top을 가능케 하는 aggregation layer"의 재확인. 네트워크가 열린 게 아니라 API 경로가 허용된 것.

### x509 / 잘못된 cluster 함정
- x509 IP SAN 오류 지속 → `kubectl config current-context`, `kind get clusters`, `kubectl get nodes`로 **보고 있는 cluster부터** 확인.
- node 이름이 `paperclip-week3-control-plane`이면 week3 cluster 재사용 중 — values 고쳐도 다른 cluster에 적용되면 소용 없음.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
