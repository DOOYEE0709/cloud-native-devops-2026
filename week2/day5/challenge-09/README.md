# Compose Architecture Challenge — Set D: Event Processing Mini Platform

> 9세션 챌린지. keyword set D를 보고 직접 설계한 비동기 이벤트 처리 stack. 기존 template 복붙이 아니라 6교시(queue/worker) + 7교시(PostgREST api+db)를 새 구조로 조합했다.

## 선택한 keyword set
- [x] **D. Event Processing Mini Platform** (ingest-api, redis-queue, processor-worker, result-api, postgres)

한 줄 설명: 이벤트를 `ingest-api`가 받아 queue에 넣고, `processor-worker`가 꺼내 postgres에 기록하면, `result-api`로 결과를 조회한다. **쓰기 진입점(ingest)과 읽기 진입점(result)이 분리**된 비동기 파이프라인.

## 구조
```text
curl → ingest-api(18120) ──LPUSH events──→ redis-queue
                                              │ BRPOP
                          processor-worker ───┘ → postgres(api.results INSERT)
curl → result-api(18121, PostgREST) ──────────→ postgres(api.results SELECT)

network: public_net(ingest/result) / queue_net(ingest·worker·redis) / data_net(worker·result·db)
```

| Service | 역할 | Image | 공개 | Network | Stateful |
|---|---|---|---|---|---|
| `ingest-api` | 이벤트 수신 → queue 적재 (producer) | node:20-alpine | host `18120` | public, queue | X |
| `redis-queue` | 이벤트 큐 | redis:7-alpine | 내부만 | queue | (휘발) |
| `processor-worker` | queue 소비 → DB 기록 (consumer) | redis:7-alpine + psql | logs만 | queue, data | X |
| `result-api` | 결과 REST 조회 | postgrest | host `18121` | public, data | X |
| `db` | 결과 저장 | postgres:16 | 내부만 | data | O (pgdata) |

## 실행 방법
```bash
docker compose config
docker compose up -d
docker compose ps
# worker가 postgresql-client 설치 후 ready 될 때까지 잠깐(약 5~10s)

# 쓰기 진입점: 이벤트 ingest
curl -s 'http://localhost:18120/ingest?event=click:42'

# queue 확인
docker compose exec redis-queue redis-cli LLEN events

# worker 처리 로그
docker compose logs processor-worker --tail 10

# 읽기 진입점: 결과 조회
curl -s http://localhost:18121/results

# 정리
docker compose down       # pgdata 보존
docker compose down -v    # 결과 데이터까지 삭제
```

## 설계 체크리스트
- [x] service 4개 이상 (5개)
- [x] `public_net` + 내부 network 2개(queue, data) 분리
- [x] 외부 진입점만 공개(ingest 18120, result 18121), DB/redis는 host 비공개
- [x] stateful: postgres(named volume `pgdata`) + redis
- [x] service 간 연결은 service name(`redis-queue`, `db`)
- [x] 증거 3종 이상: HTTP(ingest/result) + logs(worker) + Redis(LLEN) + DB(count)
- [x] failure drill: processor-worker 중지 → backlog → 복구 소진
- [x] 비밀번호 평문 기록 안 함(compose env로만, NOTES엔 비노출)
