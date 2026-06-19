# Week 2 Day 3 PostgreSQL Runtime Lab

## Purpose
PostgreSQL container는 environment variable, named volume, network, logs를 한 번에 확인하기 좋은 실습 대상이다.

## Run
```bash
docker network create paperclip-day3-net
docker volume create paperclip-day3-pgdata
docker run -d \
  --name paperclip-day3-postgres \
  --network paperclip-day3-net \
  -e POSTGRES_PASSWORD=paperclip \
  -e POSTGRES_DB=paperclip \
  -v paperclip-day3-pgdata:/var/lib/postgresql/data \
  postgres:16-alpine
```

## Check
```bash
docker logs paperclip-day3-postgres
for i in 1 2 3 4 5 6 7 8 9 10; do
  docker exec paperclip-day3-postgres pg_isready -U postgres && break
  sleep 1
done
docker exec paperclip-day3-postgres psql -U postgres -d paperclip -c "select current_database();"
```

Run SQL only after `pg_isready` reports `accepting connections` or exits with code `0`. A running container is not always a ready database.

## Cleanup
```bash
docker rm -f paperclip-day3-postgres
docker volume rm paperclip-day3-pgdata
docker network rm paperclip-day3-net
```
