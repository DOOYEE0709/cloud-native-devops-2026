# Week 2 Day 3 — Docker Image 빌드와 전달 (Dockerfile, build, tag, registry)

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Image artifact 기준 잡기 | image는 layer가 쌓인 artifact, tag는 옮겨다니고 digest는 고정, registry는 저장소 |
| 2교시 | Dockerfile contract | `FROM`, `WORKDIR`, `COPY`, `EXPOSE`, `CMD` — build가 읽는 계약을 독해 |
| 3교시 | Build context gate | `.dockerignore`로 image에 secret·불필요 파일이 들어가지 않게 막기 |
| 4교시 | Build/run/verify/scan | build → run → 동작 확인 → 취약점 scan으로 안전한 image 후보 만들기 |
| 5교시 | Layer/cache/size evidence | layer cache가 rebuild 비용을 줄이는 원리, 이미지 크기 비교 |
| 6교시 | Failure drill | build 실패 출력을 읽고 원인(문법·경로·캐시 등)을 찾기 |
| 7교시 | Tag/digest/registry gate | tag vs digest 차이, registry push와 image 공유 기준 판단 |
| 8교시 | Delivery handoff와 배움일기 | image 전달(handoff) 정리, 구름 EXP 배움일기 |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 실습 기록 및 notes |
| `session-09-challenge.md` | 추가 챌린지 세션 |
| `labs/` | Dockerfile build·실습 대상 (`static-site`, `static-site-broken`, `runtime-site`, `postgres`, `env-report`, `weekend-3tier-challenge`) |
| `assets/` | 실습 확인 스크린샷 |
