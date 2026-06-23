# Architecture 03: Frontend Platform + Config API + Redis Cache

![Frontend platform architecture](../../../assets/day5-arch-03-frontend-platform.png)

프론트엔드 플랫폼 template이다. `web`은 정적 preview를 제공하고, `config-api`는 API endpoint와 feature flag를 JSON으로 제공한다. `cache-writer`는 Redis service name `redis`로 접속해 값을 반복 기록한다.

## Network areas
| Network | 포함 service | 의미 |
|---|---|---|
| `public_net` | `web`, `config-api` | browser/curl 확인 영역 |
| `app_net` | `web`, `config-api` | frontend와 config API 영역 |
| `cache_net` | `config-api`, `redis`, `cache-writer`, `redis-cli` | backend/cache 접근 영역 |

## Run
```bash
docker compose config
docker compose up -d
docker compose ps
```

## Check
```bash
curl -I http://localhost:18088
curl -s http://localhost:18103/config
docker compose logs cache-writer --tail 20
docker compose exec redis redis-cli GET compose:cache
docker compose --profile tool run --rm redis-cli
```

Expected:

```text
HTTP/1.1 200 OK
"newCheckout":true
hit-from-cache-writer
PONG
```

## Cleanup
```bash
docker compose down
```

Redis를 named volume 없이 쓰면 container 재생성 시 data가 사라질 수 있다. cache와 database의 lifecycle 차이를 비교한다.
