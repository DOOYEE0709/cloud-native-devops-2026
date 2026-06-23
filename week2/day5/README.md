# Week 2 Day 5 — Docker Compose로 회사형 서비스 아키텍처 로컬 재현

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Compose 기본 개념과 편의성 | 긴 `docker run`을 파일로 남긴 architecture template, 공통 검증 루프(`config`/`up`/`ps`/`logs`/`down`), service name DNS·프로젝트 prefix·`--scale` |
| 2교시 | 쿠팡형 커머스 카탈로그 | frontend + catalog-api(PostgREST) + postgres, host port vs container port, connection pool 곱셈 함정, TLS/gzip offload |
| 3교시 | 당근형 백엔드 서비스 경계 | gateway 뒤 identity/payment API 분리, 장애 격리(502), Adminer 공개 위험, 자원 프로파일로 service 쪼개기, gateway SPOF |
| 4교시 | 토스형 프론트엔드 플랫폼 | runtime config·feature flag(env), cache lifecycle(휘발) vs DB(volume), Redis auth/ACL·논리DB(0~15), 로컬 포트 vs AWS VPC, profile 도구 |
| 5교시 | Nginx reverse proxy | proxy 하나로 web-a/web-b 라우팅, upstream 장애 격리(504), 502 vs 504, ALB/Ingress가 대체, compose 컨테이너 vs k8s Pod/sidecar, 기본 에러페이지/버전 숨기기 |
| 6교시 | 카카오형 메시징/worker | producer→queue→consumer 비동기, decoupling, worker 죽어도 backlog로 흡수, 핵심 지표는 200이 아니라 queue length, ack(BRPOP은 ack 없음) |
| 7교시 | API + PostgreSQL | table을 코드 없이 REST로(PostgREST), "API 떴다"≠"DB 붙었다", 404+DB에러, DB role=API 권한, 읽기 복제본·정합성(stale read) |
| 8교시 | frontend+gateway+API+DB MSA preview | Day5 종합편, gateway 정적+`/api/` proxy, failure propagation, 증상은 입구·원인은 안쪽, DB 느릴 때 인덱싱부터, Compose→k8s 다리 |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 실습 확인 기록·확인 질문·notes·Blocker Log (lab 직접 실행 + 실증 증거 기반) |
| `compose.yaml`, `html/` | day5 compose 3-tier preview 자료 |
| `labs/compose-architectures/01~07` | 교시별 architecture template (web+db, gateway+admin, web+redis, reverse-proxy, queue-worker, api-postgrest, msa-preview) |
| `labs/integration-app/` | 통합 앱 lab 자료 |
| `labs/compose-architecture-challenge/` | 9세션 챌린지 원본 workspace(빈 템플릿) |
| `session-09-challenge.md` | 9세션 챌린지 keyword set A/B/C/D 문제 |
| `challenge-09/` | 9세션 챌린지 직접 설계본 — Set D Event Processing Mini Platform (ingest-api→queue→worker→postgres→result-api) |

## 핵심 한 줄
Compose template은 여러 container의 실행 조건을 파일로 남기고, service name/network/volume/port를 통해 자주 쓰는 architecture를 재현 가능하게 만든다. 외부 진입점, 내부 service name, network area, volume lifecycle, 실패 시 확인 순서를 설명할 수 있으면 Day5 완료.

## 다음 연결
Week 3 MSA/Kubernetes에서 gateway는 Ingress/Service, API는 Deployment, DB는 StatefulSet으로, `depends_on`은 readiness probe로 이어진다.
