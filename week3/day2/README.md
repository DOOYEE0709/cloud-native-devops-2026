# Week 3 Day 2 — 운영 사고 시나리오와 상태 불일치

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | D1 Handoff 검증과 운영 관점 전환 | D1 정상 경로를 D2 사고 비교 기준으로 재분류, 관점 전환 |
| 2교시 | Ghost Pending Order | Redis 실패 시 client 503인데 DB엔 pending, `client failure ≠ DB rollback` |
| 3교시 | Readiness Gap과 Transaction Boundary | `/health` 200 ≠ 업무 일관성, readiness vs consistency |
| 4교시 | Worker Backlog와 Drain 관찰 | worker 중지 → queue backlog → 복구 drain, 추세로 판단 |
| 5교시 | Poison Message와 DLQ 필요성 | malformed message → worker_error → silent loss, DLQ 부재 |
| 6교시 | Duplicate Request와 Idempotency Gap | 같은 request_id 2번 → row 2개, request_id ≠ idempotency key |
| 7교시 | Incident Timeline과 현실형 Runbook | 한 줄 리포트 ✕, evidence 시간순 timeline + STAR |
| 8교시 | 운영 플랫폼 연결과 구름 EXP 배움일기 | K8s가 해결 vs application이 해결, observability 3기둥 |

## 실습 앱: msa-demo (Day1 공통)

```text
browser → frontend → order-api → db
order-api → redis(queue) → order-worker → db
```

Day2는 정상 경로를 다시 만들지 않고, 이 흐름이 **깨지는 경계**를 재현한다.

## 사고 시나리오 labs

```bash
cd week3/day2/labs/incident-scenarios
./01_ghost_pending_order.sh     # DB commit과 queue publish 사이 장애
COUNT=8 ./02_backlog_drain.sh   # worker 중지 중 backlog와 복구
./03_poison_message.sh          # 잘못된 queue message와 DLQ 부재
./04_duplicate_request.sh       # idempotency 없는 중복 요청
```

| Script | 사고 | 핵심 evidence |
|---|---|---|
| `01_ghost_pending_order.sh` | Ghost pending order | client 503 + DB pending + queue 0 |
| `02_backlog_drain.sh` | Worker backlog | queue length 증가 → drain → processed |
| `03_poison_message.sh` | Poison message | worker_error + queue 0 (silent loss) |
| `04_duplicate_request.sh` | Duplicate request | 같은 request_id로 order row 2개 |

> 이 script들은 정상 실행 편의용이 아니라 **사고를 재현하고 evidence를 묶어 보기 위한** 도구다.

## 봐야 할 Evidence

```bash
docker compose exec -T redis redis-cli LLEN order-events     # queue 깊이
docker compose exec -T db psql -U paperclip -d paperclip \
  -c "select id,status,request_id from orders order by id desc limit 10;"
docker compose logs --tail=80 order-worker                   # worker 처리/실패
# audit_logs: order_created / order_processed 단계 확인
```

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 실습 기록 및 notes |
| `labs/incident-scenarios/` | 사고 재현 script 4종 |
| `assets/` | 실습 확인 스크린샷 |
