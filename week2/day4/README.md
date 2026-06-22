# Week 2 Day 4 — Runtime config와 관찰(logs/inspect/exec/stats), Failure drill

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Runtime config, env file, secret masking | image 밖에서 env 주입(`-e`/`--env-file`), secret은 masking해서 기록 |
| 2교시 | Logs와 HTTP 정상 확인 | `Up`≠서비스 정상, HTTP 200과 frontend JSON contract를 분리해 확인 |
| 3교시 | Inspect와 exec로 내부 확인 | `inspect`(밖/metadata)와 `exec`(안/내부 상태)를 구분 |
| 4교시 | Stats, resource, restart policy | `docker stats`로 resource 관찰, restart policy와 crash loop의 한계 |
| 5교시 | Failure drill | 실패 출력에서 env/port/network/volume/image 중 원인 범주 좁히기 |
| 6교시 | Cleanup과 security audit | 지울 자원과 보존할 data 구분, named volume 삭제 주의 |
| 7교시 | Compose mapping handoff | 긴 `docker run` option을 `compose.yaml` 항목으로 옮길 준비 |
| 8교시 | Prometheus/Grafana observability preview | logs와 metrics의 차이, 관찰 stack 맛보기 |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 실습 기록 및 notes |
| `labs/env-report/` | env 주입 결과를 masking해서 출력하는 `report.sh` 실습 |
| `labs/http-json-state/` | HTTP 200과 JSON contract 실패를 분리하는 frontend/backend 실습 |
| `labs/compose-app/` | Day 5 Compose preview 성격의 자료 |
| `labs/observability-preview/` | Prometheus·Grafana·cAdvisor·Loki preview stack (8교시) |
| `assets/` | 실습 확인 스크린샷 |
