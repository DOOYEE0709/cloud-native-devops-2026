# Observability Preview: Prometheus, Grafana, cAdvisor, Loki

이 preview는 Day 4 본수업의 필수 범위가 아니다. 목적은 `docker logs`와 `docker stats`를 배운 뒤, 같은 관찰을 Compose 기반 stack으로 확장하면 어떤 모양이 되는지 미리 보는 것이다.

핵심 메시지:

```text
logs: 무슨 일이 있었는가
metrics: 시간에 따라 상태가 어떻게 변했는가
inspect/exec: 지금 적용된 설정과 내부 상태가 무엇인가
```

## Architecture
| Service | Port | 역할 |
|---|---:|---|
| `sample-web` | `18085` | nginx test traffic 대상 |
| `log-generator` | none | 일반 log를 계속 출력하는 sample container |
| `load-generator` | none | `sample-web`에 반복 HTTP 요청 |
| `cpu-spike` | none | 선택 profile, CPU spike 체험 |
| `cadvisor` | `18086` | 선택 profile, Docker container CPU/memory/network metrics 노출 |
| `prometheus` | `19090` | cAdvisor metrics scrape |
| `loki` | `13100` | container log 저장 |
| `promtail` | none | 선택 profile, Docker container log를 Loki로 전달 |
| `grafana` | `13000` | Prometheus metrics와 Loki logs 시각화 |

## Run
기본 실행은 host의 Docker data root를 mount하지 않는다. Docker Desktop, WSL, macOS 환경에서 `/var/lib/docker` mount가 막혀도 preview 자체는 진행되어야 하기 때문이다.

| 환경 | 권장 확인 |
|---|---|
| WSL/Linux | 기본 실행 후, 선택 심화에서만 `DOCKER_ROOT_DIR` 확인 |
| macOS Docker Desktop | Docker engine이 Linux VM 안에서 동작하므로 host mount는 선택 심화로만 진행 |

```bash
cd /mnt/d/paperclip/week2/day4/labs/observability-preview
docker compose config
docker compose --profile load config
docker compose up -d
docker compose ps
```

Expected:

```text
grafana      running
prometheus   running
loki         running
sample-web   running
load-generator running
```

## Generate traffic and logs
```bash
for i in 1 2 3 4 5; do curl -I http://localhost:18085 || true; sleep 1; done
docker compose logs sample-web --tail 20
docker compose logs log-generator --tail 20
```

Expected:

```text
HTTP/1.1 200 OK
level=info service=log-generator event=heartbeat
```

## Impact drill: stats snapshot vs metrics timeline
`docker stats`는 지금 이 순간의 값이다. 기본 preview에서는 먼저 snapshot을 확인한다. cAdvisor `host-mount` profile이 성공한 환경에서는 Prometheus/Grafana로 시간이 지나며 값이 어떻게 변했는지도 본다.

```bash
docker compose --profile load up -d cpu-spike
docker stats --no-stream
sleep 20
curl -s 'http://localhost:19090/api/v1/query?query=rate(container_cpu_usage_seconds_total%5B1m%5D)' | grep cpu-spike || true
```

Expected:

```text
cpu-spike
CPU %
```

Grafana Explore > Prometheus에서 다음 query를 넣는다.

```promql
rate(container_cpu_usage_seconds_total[1m])
```

이 query는 `host-mount` profile로 cAdvisor가 떠 있는 환경에서 의미가 있다. 기본 실행만 한 상태라면 Prometheus는 뜨지만 cAdvisor target은 없을 수 있다.

판단:

| 관찰 도구 | 보이는 것 | 한계 |
|---|---|---|
| `docker stats --no-stream` | 지금 순간 CPU/MEM | 이전 1분 동안의 추세를 보기 어렵다 |
| Prometheus query | 시간 window의 변화 | 어떤 log line 때문에 튀었는지는 별도 log 확인 필요 |
| Grafana Explore | metrics와 logs를 한 화면에서 탐색 | dashboard가 원인을 자동으로 고쳐주지는 않는다 |

CPU spike를 멈춘다.

```bash
docker compose stop cpu-spike
```

## Check Prometheus
```bash
curl -s http://localhost:19090/-/ready
curl -s 'http://localhost:19090/api/v1/query?query=up'
```

Expected:

```text
Prometheus Server is Ready.
```

Prometheus UI:

```text
http://localhost:19090
```

주의할 점:

| 위치 | 올바른 주소 |
|---|---|
| Browser에서 Prometheus 직접 열기 | `http://localhost:19090` |
| Grafana Data source URL | `http://prometheus:9090` |

Grafana는 container 안에서 실행된다. 따라서 Grafana Data source에 `http://localhost:19090`을 넣으면 Grafana 자기 자신의 `localhost`를 보게 되어 연결이 실패한다.

Example queries:

```promql
up
container_memory_usage_bytes
rate(container_cpu_usage_seconds_total[1m])
rate(container_network_receive_bytes_total[1m])
```

Filter examples:

```promql
container_memory_usage_bytes{name=~".*grafana.*"}
container_memory_usage_bytes{container_label_com_docker_compose_service="grafana"}
container_memory_usage_bytes{container_label_com_docker_compose_service=~"grafana|prometheus|loki"}
rate(container_cpu_usage_seconds_total{name=~".*cpu-spike.*"}[1m])
```

`name`은 실제 container name이고, `container_label_com_docker_compose_service`는 Compose service name이다. 수업에서는 service 단위로 설명하기 쉬운 `container_label_com_docker_compose_service`를 먼저 사용한다.

Legend cleanup:

| 원하는 legend | Grafana Legend 값 |
|---|---|
| container name만 표시 | `{{name}}` |
| Compose service만 표시 | `{{container_label_com_docker_compose_service}}` |
| image 이름만 표시 | `{{image}}` |

Grafana panel에서 query 결과 label 전체가 legend로 나오면 너무 길다. Query options의 Legend 값을 `{{name}}` 또는 `{{container_label_com_docker_compose_service}}`로 지정한다.

## Check Grafana
Open:

```text
http://localhost:13000
```

Login:

```text
admin / practice-only
```

확인할 것:

| 화면 | 확인 |
|---|---|
| Connections > Data sources | Prometheus, Loki datasource가 있는가 |
| Explore > Prometheus | `up` query가 되는가 |
| Explore > Prometheus | `host-mount` 성공 시 `container_memory_usage_bytes` query가 되는가 |
| Explore > Loki | `host-mount` 성공 시 `{job="docker"}` log query가 되는가 |
| Dashboards > Paperclip Labs | `W2D4 Observability Preview` dashboard에서 legend가 service/container 이름만 보이는가 |

Prometheus datasource 설정:

```text
URL: http://prometheus:9090
Access: Server / proxy
```

이미 UI에서 `localhost:19090`으로 저장했다면 Data source URL을 수정한다. 실습 data를 버려도 되는 경우에만 아래처럼 volume을 초기화한다.

```bash
docker compose down -v
docker compose up -d
```

## Optional host-mount profile
cAdvisor와 Promtail은 Docker engine 내부의 data root와 log file을 mount한다. 그래서 환경 영향을 크게 받는다.

WSL/Linux에서 선택적으로 시도한다.

```bash
export DOCKER_ROOT_DIR="$(docker info --format '{{.DockerRootDir}}')"
docker compose --profile host-mount up -d cadvisor promtail
docker compose ps
```

접속:

```text
http://localhost:18086
```

다음 에러가 나오면 수업에서는 실패를 정상적인 환경 차이 사례로 다룬다.

```text
Error response from daemon: error while creating mount source path '/var/lib/docker':
mkdir /var/lib/docker: read-only file system
```

의미:

| 관찰 | 해석 |
|---|---|
| `/var/lib/docker` source path 생성 실패 | Docker engine/host 경계에서 해당 경로를 만들거나 노출할 수 없음 |
| 기본 `docker compose up -d`는 성공 | preview stack 자체 문제는 아님 |
| `cadvisor`, `promtail`만 실패 | host mount 기반 수집기의 환경 제약 |

대체 확인:

```bash
docker compose logs sample-web --tail 20
docker compose logs log-generator --tail 20
docker stats --no-stream
```

## Check Loki logs
Promtail이 Docker log file을 읽을 수 있는 환경이면 Grafana Explore에서 다음 query가 동작한다.

```logql
{job="docker"}
```

curl로 직접 확인할 때는 log query가 시간 범위를 필요로 하므로 `query_range`를 사용한다. `query` endpoint에 같은 LogQL을 넣으면 instant query라서 실패할 수 있다.

WSL/Linux:

```bash
now_ns=$(date +%s%N)
start_ns=$((now_ns - 300000000000))

curl -G -s 'http://localhost:13100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="docker"}' \
  --data-urlencode "start=$start_ns" \
  --data-urlencode "end=$now_ns" \
  --data-urlencode 'limit=5'
```

macOS:

```bash
end_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
start_time=$(date -u -v-5M +"%Y-%m-%dT%H:%M:%SZ")

curl -G -s 'http://localhost:13100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="docker"}' \
  --data-urlencode "start=$start_time" \
  --data-urlencode "end=$end_time" \
  --data-urlencode 'limit=5'
```

Expected:

```text
"status":"success"
"job":"docker"
```

환경에 따라 Docker Desktop/WSL의 log path mount가 제한될 수 있다. 이 경우에도 Day 4의 기본 log 확인은 다음 명령으로 계속 가능하다.

```bash
docker compose logs sample-web
docker compose logs log-generator
```

## Troubleshooting hints
| Symptom | First check | Likely cause |
|---|---|---|
| `docker-credential-desktop.exe` not found | `docker compose up -d` output | WSL이 Windows Docker credential helper를 찾지 못함 |
| Grafana login fails | `docker compose logs grafana` | password typo or old `grafana-data` volume |
| Prometheus has no cAdvisor target | `docker compose logs prometheus` | scrape target unavailable |
| Grafana Prometheus data source fails | Grafana Data source URL | `localhost:19090`이 아니라 `http://prometheus:9090` 사용 |
| `Post "http://localhost:19090/api/v1/query": connect: connection refused` | Grafana Data source URL | Grafana가 아직 잘못된 URL을 보고 있음. Data source 편집 화면을 새로 열고 URL을 `http://prometheus:9090`으로 저장 |
| cAdvisor container exits | `docker compose logs cadvisor` | host mount/device restriction |
| Loki has no logs | `docker compose logs promtail` | Docker log path mount restriction |
| `mkdir /var/lib/docker: read-only file system` | `docker compose --profile host-mount up -d cadvisor promtail` output | Docker Desktop/WSL host mount source path restriction |
| port already allocated | `docker compose ps`, `docker ps` | local port conflict |
| CPU spike가 계속 남음 | `docker compose ps` | `cpu-spike` profile container stop 필요 |

### WSL/Linux troubleshooting
| 증상 | 확인 명령 | 조치 |
|---|---|---|
| `docker-credential-desktop.exe` 오류 | `cat ~/.docker/config.json` | 실습 중에는 임시 config로 우회: `mkdir -p /tmp/paperclip-docker-config && printf '{}\n' > /tmp/paperclip-docker-config/config.json`, 이후 `DOCKER_CONFIG=/tmp/paperclip-docker-config docker compose up -d` |
| cAdvisor가 `/var/lib/docker`를 못 읽음 | `docker info --format '{{.DockerRootDir}}'` | `export DOCKER_ROOT_DIR="$(docker info --format '{{.DockerRootDir}}')"` 후 `docker compose --profile host-mount up -d cadvisor promtail` |
| `mkdir /var/lib/docker: read-only file system` | 에러 출력의 mount source path | 기본 `docker compose up -d`로 돌아가고 `docker compose logs`, `docker stats` 중심으로 진행 |
| `port is already allocated` | `docker ps --format 'table {{.Names}}\t{{.Ports}}'` | 충돌 중인 container를 멈추거나 compose port를 변경. 이 lab은 cAdvisor를 `18086`으로 사용 |
| Loki API에서 `log queries are not supported as an instant query type` | 호출한 URL 확인 | `/loki/api/v1/query`가 아니라 `/loki/api/v1/query_range` 사용 |

### macOS Docker Desktop troubleshooting
| 증상 | 확인 명령 | 조치 |
|---|---|---|
| `date +%s%N` 결과가 이상함 | `date +%s%N` | macOS용 `date -u -v-5M` 예시를 사용 |
| Promtail이 Docker log를 못 읽음 | `docker compose logs promtail` | Docker Desktop VM 내부 log path 제한일 수 있음. Grafana/Loki가 비어 있으면 `docker compose logs sample-web`, `docker compose logs log-generator`로 일반 로그 확인 |
| cAdvisor가 device/mount 오류로 종료 | `docker compose logs cadvisor` | Docker Desktop 환경 제약일 수 있음. 이 경우 `docker stats`와 Prometheus/Grafana UI 확인을 우선하고, metrics target 실패 원인을 토론 포인트로 삼음 |
| Grafana는 뜨는데 Prometheus target이 down | `curl -s 'http://localhost:19090/api/v1/query?query=up'` | cAdvisor scrape 실패 가능성. Docker Desktop VM mount/device 제약 여부 확인 |

## Cleanup
```bash
docker compose down
```

Data reset까지 필요할 때만 실행한다.

```bash
docker compose down -v
```

`down -v`는 Grafana/Loki volume을 삭제한다. 다음 실행 때 datasource는 provisioning으로 다시 생성되지만, 사용자가 만든 dashboard는 사라질 수 있다.
