# Week 2 Day 3 Env Report Lab

## Run
```bash
docker run --rm \
  -e APP_ENV=practice \
  -e APP_PORT=8080 \
  -e FEATURE_FLAG=on \
  -e DB_HOST=postgres \
  -e DB_PORT=5432 \
  -v "$PWD/report.sh:/workspace/report.sh:ro" \
  alpine:3.20 sh /workspace/report.sh
```

## Expected
```text
APP_ENV=practice
APP_PORT=8080
FEATURE_FLAG=on
DB_HOST=postgres
DB_PORT=5432
```
