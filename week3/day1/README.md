# Week 3 Day 1 — MSA 토폴로지와 서비스 간 통신

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Week2 10분 요약 + MSA를 운영 토폴로지로 보기 | 단일 container 정상 ≠ 전체 서비스 정상, build vs image |
| 2교시 | Monolith vs MSA | 독립 배포 vs 운영 비용, service 분리는 협상(granularity), 로그 통합 |
| 3교시 | 인프라 엔지니어가 MSA에서 알아야 할 것 | service contract 표, healthcheck, secret 외부 관리 |
| 4교시 | 표준 MSA 실습 앱 토폴로지 | `frontend→api→db`, `worker→api`, nginx proxy, network 격리 |
| 5교시 | Compose로 전체 서비스 실행 | `up --build -d`, baseline 수집, `--build` vs `--force-recreate` |
| 6교시 | 서비스 간 통신 확인 | host vs container 기준, `localhost` 함정, request id |
| 7교시 | 장애 시나리오 1 - API URL, DB host, 환경변수 | API/DB 중지·DB_HOST 오류 증상 구분, 장애 리포트 |
| 8교시 | 구름 EXP 배움일기 - MSA 토폴로지와 연결 실패 증거 | Day1 evidence 정리, Day2로 넘길 질문 |

## 실습 앱: msa-demo

```text
browser → frontend(nginx) → api → db
worker  → api → db
```

| Service | 실행 기준 | 외부 접근 | 내부 주소 |
|---|---|---|---|
| `frontend` | `nginx:1.27-alpine` | `localhost:18083` | `frontend:80` |
| `api` | `build: ./api` | `localhost:18084` (debug) | `api:8080` |
| `worker` | `build: ./worker` | 없음 | `worker` |
| `db` | `postgres:16-alpine` | 없음 | `db:5432` |

## 핵심 명령

```bash
cd week3/day1/labs/msa-demo
docker compose config                       # 실행 전 설정 확인
docker compose up --build -d                # 전체 서비스 실행
docker compose ps                           # 상태 확인
curl -s http://localhost:18083/api/status   # frontend 경유 API
curl -s http://localhost:18084/health       # API 직접 health
docker compose logs --tail=60 api worker    # 로그 증거
docker compose down                         # 정리 (down -v: DB volume까지)
```

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 실습 기록 및 notes |
| `assets/` | 실습 확인 스크린샷 |
