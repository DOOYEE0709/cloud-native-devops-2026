# Compose Architecture Challenge Notes — Set D

## Basic Info
| 항목 | 작성 |
|---|---|
| 선택한 keyword set | **D. Event Processing Mini Platform** |
| 한 줄 설명 | 이벤트를 ingest-api가 queue에 넣고, processor-worker가 꺼내 postgres에 기록, result-api로 조회. 쓰기/읽기 진입점 분리 비동기 파이프라인 |

## Architecture Summary
| Service | 역할 | Image/build | 공개 여부 | Network | Stateful 여부 |
|---|---|---|---|---|---|
| `ingest-api` | 이벤트 수신 → LPUSH (producer) | node:20-alpine (raw TCP redis) | host `18120` | public_net, queue_net | X |
| `redis-queue` | 이벤트 큐 (LPUSH/BRPOP) | redis:7-alpine | 내부만 | queue_net | 휘발(volume 없음) |
| `processor-worker` | BRPOP → postgres INSERT (consumer) | redis:7-alpine + `apk add postgresql-client` | logs만 | queue_net, data_net | X |
| `result-api` | api.results를 REST로 (read) | postgrest:v12.2.8 | host `18121` | public_net, data_net | X |
| `db` | 처리 결과 저장 | postgres:16 | 내부만 | data_net | O (named volume pgdata) |

## Traffic Path
| 구간 | 연결 | 확인 증거 |
|---|---|---|
| 외부 진입(쓰기) | curl → ingest-api:18120 `/ingest?event=` | `{"queued":"click:42","redis":":1"}` |
| queue 적재 | ingest-api → `redis-queue` (LPUSH events) | `redis":1` (list 길이) |
| queue 소비 | processor-worker → `redis-queue` (BRPOP events) | worker log `processed: click:42` |
| data 기록 | processor-worker → `db` (INSERT api.results) | DB count 증가 |
| 외부 진입(읽기) | curl → result-api:18121 `/results` | postgres 결과 JSON |

## Network Design
| Network | 포함 service | 이유 |
|---|---|---|
| `public_net` | ingest-api, result-api | 외부 curl 진입점(쓰기/읽기) |
| `queue_net` | ingest-api, redis-queue, processor-worker | 이벤트 enqueue/dequeue 영역 |
| `data_net` | processor-worker, result-api, db | DB read/write 영역 (db는 여기에만) |

> ingest-api는 public+queue(읽기 DB 접근 없음), result-api는 public+data(queue 접근 없음), worker만 queue+data 양쪽 — 역할별로 닿는 영역이 다르다.

## Runtime Config
| Service | Env/config | service name 사용 |
|---|---|---|
| ingest-api | `REDIS_HOST=redis-queue` | O (`redis-queue:6379`) |
| processor-worker | `psql -h db`, `redis-cli -h redis-queue` | O |
| result-api | `PGRST_DB_URI=...@db:5432/app` | O (`db`) |
| (비밀번호) | compose env로만 주입, 본 문서엔 비노출 | — |

## Evidence
| 확인 항목 | 명령 | 핵심 결과 |
|---|---|---|
| Compose config | `docker compose config --services` | 5개 — db, redis-queue, ingest-api, processor-worker, result-api |
| Running state | `docker compose ps` | ingest-api(18120)·result-api(18121)만 host 공개, 나머지 내부 |
| HTTP(쓰기) | `curl '.../ingest?event=click:42'` | `{"queued":"click:42","redis":":1"}` |
| HTTP(읽기) | `curl http://localhost:18121/results` | 처리된 이벤트 JSON (id/event/processed_at) |
| Logs | `docker compose logs processor-worker` | `processor-worker ready` → `processed: click:42/view:7/purchase:99` |
| Redis/Queue | `docker compose exec redis-queue redis-cli LLEN events` | 처리 후 `0` |
| DB | `docker compose exec db psql -U postgres -d app -c "SELECT count(*) FROM api.results;"` | drill 후 `6` |

## Load/Pressure Notes
| 관점 | service | 이유 | 먼저 볼 증거 |
|---|---|---|---|
| traffic 집중 | ingest-api, result-api | 외부 요청이 두 진입점에 몰림 | publish 성공률, /results latency |
| CPU 부하 후보 | processor-worker | 이벤트 처리 로직이 무거우면 가장 큼 | worker throughput, 처리 지연 |
| memory/state 부하 후보 | redis-queue backlog, postgres api.results | 처리 못 따라가면 queue 누적 / 결과 table 무한 증가 | `LLEN events`, table row 수 |
| scale out 후보 | processor-worker | queue가 쌓이면 worker를 늘려 처리량↑ (ingest 안 건드림) | `LLEN events` 증가 추세 |

## Failure Drill
| 실패 주입 | 관찰 증상 | 첫 확인 명령 | 복구 | 배운 점 |
|---|---|---|---|---|
| `docker compose stop processor-worker` | ingest는 **HTTP 200** 유지, `LLEN events`=3으로 backlog, `/results`는 3건 그대로(증가 안 함) | `docker compose exec redis-queue redis-cli LLEN events` | `docker compose up -d processor-worker` → backlog 소진, results 6건 | **ingest와 처리가 decoupling** — 소비자 죽어도 이벤트 유실 없이 queue에 쌓였다가 복구 후 처리. 단 queue 메모리 한계까지만 |

## Cleanup
| 명령 | 선택 이유 | data 삭제 여부 |
|---|---|---|
| `docker compose down` | 컨테이너/네트워크만 정리, 결과 데이터(pgdata) 보존 | 보존 |
| `docker compose down -v` | 결과 table까지 초기화하고 싶을 때 | `pgdata` 삭제 |
| (redis-queue) | volume 없음 → `down`만으로 큐 내용 소멸 | 항상 삭제 |

## Week 3 Bridge
| 질문 | 내 답 |
|---|---|
| Kubernetes로 옮기면 어떤 service가 Deployment가 될까 | ingest-api, processor-worker, result-api (stateless) → Deployment. result-api/ingest-api 앞엔 Service+Ingress |
| Stateful하게 다뤄야 할 것은 | postgres → StatefulSet+PV (또는 관리형 RDS). redis-queue는 유실 허용이면 Deployment, 보장 필요하면 영속화/전용 브로커(SQS/Kafka) |
| readiness/health check가 필요한 service | 전부. 특히 worker는 db/redis ready 후 동작해야(`depends_on` 대신 probe). 지금은 worker가 `pg_isready`로 대기 |
| 가장 먼저 scale out할 service | processor-worker — queue backlog(`LLEN`)가 쌓이면 consumer를 늘린다 (ingest/result는 traffic 따라 별도) |

## 한 줄 회고
HTTP 200(ingest 접수)과 실제 처리(worker→DB)가 다르다는 걸 직접 봤다. 핵심 지표는 200이 아니라 **queue length**와 **result table 증가**. worker를 죽였을 때 ingest는 멀쩡하고 backlog만 쌓이는 게 비동기 구조의 장애 흡수다.
