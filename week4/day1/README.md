# Week 4 Day 1 — 운영 가능한 Workload와 Helm 기반 관찰

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Week3 요약 + 운영 가능한 workload 기준 | Pod/Deployment/Service는 시작점. 운영엔 config·secret·health·resource·metric이 함께 필요 |
| 2교시 | Helm 기본 개념 | chart·repository·release·namespace·values·upgrade·rollback·uninstall 구분. `apply -f url`로 안 끝냄 |
| 3교시 | Helm 공통 설치 루프 | repo add/update → template → upgrade --install → status/values → rollback/uninstall. deployed ≠ Ready, 렌더/실물로 확인 |
| 4교시 | ConfigMap과 Secret | image 밖 runtime config 경계(`.env` 감각 확장). envFrom 주입, Secret base64는 암호화 아님, 변경 후 rollout 필요 |
| 5교시 | Probe와 Readiness | readiness=traffic 기준(endpoint 제외, 재시작 X), liveness=restart 기준. `0/1 Running`+`RESTARTS 0` |
| 6교시 | Resource Requests/Limits | requests=배치 약속(scheduler), limits=사용 상한. mem 초과=OOMKilled(137), CPU 초과=throttling. `m`=milli |
| 7교시 | Metrics Server 설치와 관찰 | kubectl top·HPA의 실시간 metric 공급원. APIService(aggregation)로 동작. 선언값 vs 실사용. Prometheus와 목적 다름 |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 핵심 정리·실습 확인 기록·확인 질문·notes·Blocker Log |
| `labs/workload-basics/` | 운영형 Deployment·Service·ConfigMap·Secret, probe/OOM 실험 manifest |
| `labs/helm-metrics-server/values.yaml` | kind/local 실습용 metrics-server Helm values (`--kubelet-insecure-tls`) |

## 실습 환경

kind cluster `paperclip-w4`(node `paperclip-w4-control-plane`), namespace `week4`.
설치 add-on은 metrics-server(`kube-system`) 하나이며 3교시 Helm 루프로 설치한다.

## 핵심 한 줄

동일 image를 환경에 종속시키지 않고(ConfigMap/Secret), traffic·restart 상태를 정확히 판단하고(probe), 배치·상한을 선언하고(requests/limits), 실사용량을 관찰(metrics-server)할 수 있어야 "운영 가능한 workload"다. add-on 설치는 명령 하나가 아니라 Helm 설치 루프(repo→values→install→검증)로 기록한다.

## 다음 연결

W4D2에서 ingress-nginx를 같은 Helm 루프로 설치해 외부 traffic 진입점을 붙인다. 5교시 readiness→endpoint 연결이 그대로 외부 라우팅으로 확장되고, 6·7교시 resource/metric은 W4D3 Prometheus/Grafana와 HPA로 이어진다.
