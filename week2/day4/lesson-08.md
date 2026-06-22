# 8교시: Prometheus/Grafana observability preview

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker compose config` / `docker compose --profile load config` | observability-preview 스택 구성 확인 (profile 포함 시 cpu-spike 등 추가) |
| `docker compose up -d` / `docker compose ps` | 기본 스택(sample-web, log-generator, loki, prometheus, grafana) 기동 확인 |
| `for i in 1..5; do curl -I http://localhost:18085; sleep 1; done` | `HTTP/1.1 200 OK` 반복 — test traffic 생성 |
| `docker compose logs sample-web --tail 20` | nginx access log 확인 |
| `docker compose logs log-generator --tail 20` | `level=info service=log-generator event=heartbeat` 확인 |
| Grafana `http://localhost:13000` (admin / practice-only) | Explore에서 metrics/logs 탐색 |
| `docker compose --profile load up -d cpu-spike` + `docker stats --no-stream` | snapshot으로 CPU 순간값 확인 |
| Grafana Explore: `rate(container_cpu_usage_seconds_total[1m])` | 같은 spike를 **시간 흐름(time series)** 으로 확인 — stats와 대비 |
| Prometheus `up` | scrape 대상이 살아있는지 확인 |
| Loki `{job="docker"}` (query_range) | Docker container log를 시간 범위로 query |
| (선택 심화) `docker compose --profile host-mount up -d cadvisor promtail` | container metrics·Docker log 수집 시도. 환경 따라 `read-only file system`으로 실패 가능 |
| `docker compose stop cpu-spike` / `docker compose down` | spike 중지 / 스택 정리 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 이 교시의 목표는? | dashboard를 잘 꾸미는 게 아니다. `docker logs`/`stats`로 보던 증거가 Compose + observability stack에서 **metrics/logs로 확장된다는 감각**을 잡는 것이다. |
| `docker stats`와 Prometheus query는 무엇이 다른가? | `stats --no-stream`은 **지금 순간**의 CPU/MEM snapshot이고, Prometheus는 `rate(...[1m])`처럼 **시간 window의 변화(추세)** 를 본다. spike가 언제부터 올랐는지는 stats로 못 보고 Prometheus로 본다. |
| metrics와 logs의 역할 차이는? | metrics(Prometheus/Grafana)는 "수치가 어떻게 변했나", logs(Loki/Grafana)는 "그때 무슨 일이 있었나"를 본다. spike 시점은 metrics로 찾고, 원인 줄은 logs로 확인하는 식으로 같이 쓴다. |
| 스택 각 구성요소 역할은? | cAdvisor가 container metrics를 노출 → Prometheus가 scrape/저장/query, promtail이 Docker log를 전달 → Loki가 저장, Grafana는 둘 다 탐색하는 UI다. (cAdvisor·promtail은 host data root를 읽어야 해서 **선택 심화**다) |
| 왜 cAdvisor/Promtail은 기본이 아닌가? | 둘은 Docker engine 내부 data root(`/var/lib/docker`)를 bind mount해야 한다. Docker Desktop/WSL/macOS에서는 이 경로가 read-only로 막혀 `mkdir ...: read-only file system`이 난다. 그래서 기본 실행에서 빼고 `host-mount` profile로 분리했다. |
| Loki를 API로 직접 query할 때 주의점은? | log query는 **시간 범위가 필요**하다. Grafana Explore는 화면 time range를 자동으로 보내지만, `curl`로 직접 호출하면 `query_range`에 start/end를 명시해야 한다. |
| dashboard가 있으면 원인을 자동으로 알려주나? | 아니다. Grafana는 metrics/logs를 한 화면에서 **탐색**하게 해줄 뿐, 원인을 고쳐주지 않는다. 결국 어떤 command/output을 같이 봐야 한다. |
| preview "성공" 기준은? | **기본 실행**: sample-web·log-generator·loki·prometheus·grafana가 올라오고 `docker compose logs`로 일반 로그를 확인 + Grafana/Prometheus UI가 뜨면 성공이다. cAdvisor/Promtail metrics는 `host-mount` profile 성공 시의 **선택 보너스**이고, 실패해도 preview 실패로 보지 않는다. |

## notes

### 단일 명령 → observability stack 확장

`logs`, `exec`, `stats`만 보면 명령어 목록 같지만, 운영에서는 dashboard·time series·log query로 확장된다. Day 4 마지막은 이 확장을 미리 보는 것이다.

```text
docker logs           : 지금 무슨 일이 있었는가
docker exec           : container 안쪽을 직접 확인한다
docker stats          : 지금 순간의 resource를 본다
Prometheus/Grafana    : resource 변화의 흐름(추세)을 본다
Loki/Grafana          : log를 query하고 탐색한다
```

### 스택 구성요소 — 누가 무엇을 하나

| 구성요소 | 역할 | metrics/logs | 실행 |
|---|---|---|---|
| Prometheus | metrics를 scrape·저장·query (PromQL) | metrics 저장/질의 | 기본 |
| Loki | log 저장·query | logs 저장/질의 | 기본 |
| Grafana | metrics·logs를 한 화면에서 탐색하는 UI | 둘 다 탐색 | 기본 |
| sample-web / log-generator | test traffic·sample log 생성 | — | 기본 |
| cAdvisor | Docker container의 CPU/메모리 등 metrics 노출 | metrics 수집원 | **선택**(host-mount) |
| promtail | Docker container log를 Loki로 전달 | logs 수집원 | **선택**(host-mount) |

흐름: **cAdvisor → Prometheus**(metrics), **promtail → Loki**(logs), 그리고 **Grafana가 둘을 함께** 본다. 단, **수집원인 cAdvisor·promtail은 선택 심화**다 — host data root를 읽어야 해서 환경에 따라 막힌다. 그래서 기본 실행에서는 Prometheus/Loki/Grafana가 떠도 container metrics·Docker log 수집은 비어 있을 수 있다.

수집 방향이 metrics와 logs가 반대인 게 포인트다.

| | metrics | logs |
|---|---|---|
| 수집원 | cAdvisor | promtail |
| 저장/질의 | Prometheus | Loki |
| 방향 | **Prometheus가 pull** (가서 긁어옴) | **promtail이 push** (Loki로 밀어넣음) |
| 시각화 | Grafana (둘 다 한 화면) | |

즉 Prometheus는 cAdvisor에 주기적으로 **가서 당겨오고(pull)**, 로그는 promtail이 Loki로 **밀어넣는다(push)**. 그래서 Prometheus 쪽은 "긁을 대상(target)이 살아있나"를 `up`으로 확인하고, 로그 쪽은 promtail이 제대로 보내고 있나를 본다.

### Impact drill — snapshot vs time series

CPU spike를 일부러 만들고 `docker stats`와 Prometheus를 비교하는 게 이 교시의 핵심 체험이다.

| 관찰 도구 | 보이는 것 | 한계 |
|---|---|---|
| `docker stats --no-stream` | 지금 순간 CPU/MEM | 이전 1분의 추세를 보기 어렵다 |
| Prometheus query | 시간 window의 변화 | 어떤 log line 때문에 튀었는지는 별도 log 확인 필요 |
| Grafana Explore | metrics와 logs를 한 화면에서 | dashboard가 원인을 자동으로 고쳐주진 않는다 |

핵심: **metrics는 "언제/얼마나" 튀었는지, logs는 "왜" 튀었는지**를 답한다. 둘은 대체가 아니라 보완이다(4교시 "stats는 snapshot" 연결).

#### 스파이크 트래픽(spike traffic)이란

짧은 시간에 트래픽이 급격히 치솟았다가 빠르게 떨어지는 패턴이다. 그래프가 뾰족한 못(spike) 모양이라 그렇게 부른다. 8교시의 `cpu-spike`/`load-generator`가 이걸 일부러 만들어보는 것이다.

```text
요청량
  │        ╱╲
  │       ╱  ╲
  │______╱    ╲______   평소 → 급증 → 급감
        시간
```

| 왜 생기나 | 예 |
|---|---|
| 이벤트성 몰림 | 티켓팅 오픈, 수강신청, 한정판 드롭 |
| 외부 노출 | 광고·방송 직후, 인플루언서 링크, 뉴스 메인 |
| 자동화/공격 | 봇 크롤링, DDoS |
| 배치성 부하 | 정각마다 도는 cron, 정산 작업 |

왜 이 교시와 직결되나: **스파이크는 snapshot으로 놓치기 쉽다.** `docker stats --no-stream`은 마침 그 순간을 안 찍으면 안 보이고, "언제 튀었다 언제 가라앉았다"는 Prometheus 같은 **time series**라야 그래프로 남는다. 즉 스파이크는 추세 관측이 필요한 대표 사례라서 stats vs Prometheus 대비의 핵심 예시가 된다.

대응 방식(참고): **오토스케일링**(트래픽 늘면 자동 증설·줄면 회수, ELB의 "Elastic"과 같은 결), **대기열/큐잉**(티켓팅 대기열로 완충), **rate limiting**(봇·공격성 스파이크 차단).

### Loki API는 시간 범위가 필수

log query는 시간 범위가 있어야 한다. Grafana Explore는 화면 time range를 자동으로 보내지만, `curl`로 직접 호출하면 `query_range` endpoint에 start/end를 명시해야 한다. `date` 명령이 OS마다 달라 start/end 만드는 방식도 갈린다 — **macOS는 BSD `date`, WSL/Linux는 GNU `date`**.

```bash
# macOS (BSD date) — RFC3339 문자열
end_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
start_time=$(date -u -v-5M +"%Y-%m-%dT%H:%M:%SZ")
curl -G -s 'http://localhost:13100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="docker"}' \
  --data-urlencode "start=$start_time" --data-urlencode "end=$end_time" \
  --data-urlencode 'limit=5'
```

```bash
# WSL/Linux (GNU date) — 나노초 epoch
now_ns=$(date +%s%N)
start_ns=$((now_ns - 300000000000))   # 5분 = 300,000,000,000 ns
curl -G -s 'http://localhost:13100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="docker"}' \
  --data-urlencode "start=$start_ns" --data-urlencode "end=$now_ns" \
  --data-urlencode 'limit=5'
```

Loki는 **RFC3339 문자열·나노초 epoch 둘 다** 받는다. 형식이 달라서가 아니라 OS별 `date`가 만들기 편한 표현이 달라서 두 버전으로 나뉜 것뿐이다.

| | macOS (BSD date) | WSL/Linux (GNU date) |
|---|---|---|
| 나노초 `%N` | 미지원 | `%s%N` 지원 |
| 5분 전 | `-v-5M` | `-d '5 min ago'` 또는 epoch 뺄셈 |
| 넘기는 형식 | RFC3339 문자열 | 나노초 정수 |

> macOS는 Linux가 아니라 **BSD(Darwin) 계열**이라 기본 도구가 GNU와 다르다. `date`뿐 아니라 `sed`, `ls` 등도 옵션 차이가 난다(앞서 본 `sed -i` 등). 그래서 강의도 macOS와 WSL/Linux 명령을 따로 제공한다.

### 포트 두 세계 — 브라우저 접속(19090) vs 컨테이너 내부 접속(9090)

실습에서 가장 헷갈리는 지점. **누가 접속하느냐**에 따라 쓰는 주소가 다르다.

| 상황 | 누가 접속 | 쓰는 주소 |
|---|---|---|
| 웹사이트로 Grafana/Prometheus 열기 | 호스트(맥) 브라우저 | `localhost:19090` (외부 publish 포트) |
| Grafana 데이터소스에서 Prometheus 연결 | **Grafana 컨테이너** | `http://prometheus:9090` (서비스 이름 + 내부 포트) |

```text
[너] ──브라우저──> localhost:19090 ──> Grafana 화면 진입
                                          │ (이제 Grafana 안에 있음)
[Grafana] ──내부 네트워크──> prometheus:9090 ──> Prometheus
```

핵심: **밖에서 들어올 땐 `19090`, 안에서 부를 땐 `9090`.**

- 들어갈 때 (호스트 → 컨테이너): 너는 호스트에 있으니 외부 포트 `localhost:19090` (`-p 19090:9090`으로 매핑된 바깥쪽)
- 들어간 다음 (컨테이너 → 컨테이너): Grafana는 이미 Docker 내부에 있으니 **서비스 이름 + 내부 포트** `prometheus:9090`

왜 `localhost:19090`을 데이터소스에 넣으면 안 되나: 그 접속을 시도하는 건 브라우저가 아니라 **Grafana 컨테이너**다. Grafana 입장에서 `localhost`는 호스트가 아니라 **자기 자신**이라 Prometheus가 없어 `connection refused`가 난다. 또 외부 포트 `19090`은 호스트 쪽에만 존재해서 컨테이너끼리는 모른다 — 내부 포트 `9090`을 써야 한다.

| 데이터소스 URL | 결과 |
|---|---|
| `http://localhost:19090` | ❌ Grafana의 localhost = 자기 자신, refused |
| `http://prometheus:9090` | ✅ 같은 network에서 서비스 이름 + 내부 포트 |

이건 lesson-05의 "wrong network / `bad address`"와 같은 원리다 — **같은 Docker network 안에서는 컨테이너를 서비스 이름으로 부르고 내부 포트를 쓴다.** 외부 publish 포트(`1xxxx`)는 호스트에서 들어갈 때만 의미가 있다.

### 선택 심화 — cAdvisor/Promtail host-mount와 성공 기준

기본 실행은 host의 Docker data root를 mount하지 않는다. cAdvisor·Promtail만 `/var/lib/docker`를 bind mount해야 하는데, Docker Desktop/WSL/macOS에서 이 경로가 read-only로 막히는 경우가 많기 때문이다. 그래서 둘을 `host-mount` profile로 분리했다.

```bash
docker compose --profile host-mount up -d cadvisor promtail
```

실패하면 다음 에러가 난다.

```text
Error response from daemon: error while creating mount source path '/var/lib/docker':
mkdir /var/lib/docker: read-only file system
```

이건 container 내부 문제가 아니라 **Docker engine이 bind mount source를 만들 수 없는 환경**이라는 뜻이다(2교시 "환경 차이는 runtime 문제"와 같은 결). 실패해도 preview 실패가 아니다.

| 성공 단계 | 기준 |
|---|---|
| **기본 (필수)** | sample-web·log-generator·loki·prometheus·grafana 기동 + `docker compose logs`로 일반 로그 확인 + Grafana/Prometheus UI 접속 |
| **선택 보너스** | `host-mount` profile 성공 시 → container metrics(cAdvisor), Docker log 수집(Promtail)까지 확인 |

즉 Grafana Explore의 `container_cpu_usage...`, `{job="docker"}` 같은 쿼리는 **host-mount profile이 성공해야** 데이터가 찬다. 기본 실행만으로는 비어 있을 수 있고, 그게 정상이다.

### Grafana provisioning — 대시보드/데이터소스 자동 주입

Grafana 대시보드와 데이터소스는 손으로 만들지 않아도 된다. compose가 provisioning 폴더를 Grafana 컨테이너에 mount하고, Grafana가 뜰 때 이를 읽어 **자동으로 주입**한다.

```yaml
# compose의 grafana 서비스
volumes:
  - ./grafana/provisioning:/etc/grafana/provisioning:ro
```

| 파일 | 역할 |
|---|---|
| `datasources/datasources.yml` | Prometheus·Loki 데이터소스를 자동 등록 (URL이 `http://prometheus:9090`으로 이미 박혀 있음) |
| `dashboards/dashboards.yml` | "이 경로의 JSON을 `Paperclip Labs` 폴더에 자동 로드하라"는 **loader 설정** (대시보드 내용 아님) |
| `dashboards/w2d4-observability-preview.json` | 실제 대시보드 내용(패널·쿼리) |

핵심: `dashboards.yml`은 대시보드가 아니라 **불러오는 안내문**이고, 실제 그래프는 옆 JSON에 있다. 둘 다 compose가 자동 주입하므로 **`docker compose up -d`만 하면** Grafana → Dashboards → `Paperclip Labs`에 같은 대시보드가 떠 있다. 데이터소스도 이미 자동 등록돼 있어 원래는 손으로 URL을 고칠 필요가 없다(잘못 저장한 경우에만 수정).

단, **대시보드 틀은 떠도 패널은 데이터가 흘러야 채워진다.** `up`·기본 metrics는 Prometheus만으로 차지만, container CPU/메모리·Docker 로그 패널은 수집원(cAdvisor/Promtail = host-mount)이 있어야 한다(위 "선택 심화" 참고). macOS에서 패널이 "No data"인 두 경우는 아래 두 섹션에서 다룬다 — 수집원이 아예 안 뜬 경우, 또는 떠도 라벨이 안 맞는 경우.

### 강사님 대시보드 쿼리가 macOS에서 No data인 이유 — cAdvisor 라벨 미부착

provisioning으로 깔린 대시보드는 떠 있는데 패널이 **No data**일 때, 수집(cAdvisor)이 되는데도 안 보일 수 있다. 원인은 **강사님 쿼리가 거는 라벨이 macOS cAdvisor엔 안 붙어서**다.

강사님 대시보드 쿼리는 이런 라벨로 필터한다:

```promql
rate(container_cpu_usage_seconds_total{name!="", container_label_com_docker_compose_project="observability-preview"}[1m])
container_memory_usage_bytes{container_label_com_docker_compose_project="observability-preview", container_label_com_docker_compose_service!=""}
```

그런데 macOS Docker Desktop에서 실제로 나오는 metric의 라벨을 보면:

```text
container_cpu_usage_seconds_total{cpu="total", id="/docker/03566c23...", instance="cadvisor:8080", job="cadvisor"}
```

라벨이 `cpu`, `id`, `instance`, `job`뿐이다. **`name`도, `container_label_com_docker_compose_*`도 없다.** 컨테이너 구분이 `id="/docker/<해시>"`로만 된다. 그래서 `name!=""`·compose 라벨 필터에 전부 걸러져 No data가 된다.

왜: cAdvisor가 `name`·compose 라벨을 붙이려면 Docker engine의 컨테이너 메타데이터를 읽어야 하는데, macOS는 engine이 VM 안에서 돌아 cAdvisor가 그 메타데이터에 못 닿는다. **수치는 수집되지만(cgroup `id`까지) 이름·라벨은 못 붙는다.** Linux였으면 다 붙었을 값이다.

**확인법:** Prometheus(`localhost:19090`)에서 `count(container_cpu_usage_seconds_total) by (name)` 실행 → `name` 라벨이 비어있으면 확정.

**대체 쿼리 (보고 싶을 때):** 패널 Edit해서 `name`/compose 라벨 대신 `id`로 거른다.

```promql
# CPU
rate(container_cpu_usage_seconds_total{id=~"/docker/.+", cpu="total"}[1m])
# Memory
container_memory_usage_bytes{id=~"/docker/.+"}
```

`id=~"/docker/.+"`는 개별 컨테이너만 잡는다(부모 `/`, `/docker`, `/restricted` 제외). 범례가 이름 대신 해시로 나오는 건 감수한다(이름 라벨이 없으니까). 단 provisioning 대시보드를 손으로 고치는 거라 임시이며, `down -v`/재시작 시 원복된다.

**판단:** 이건 고장이 아니라 **runtime 환경 차이**다. metric 수집까지 확인했으면 preview는 성공이고, 강사님이 주신 대시보드가 비는 건 macOS cAdvisor 한계로 관찰 거리로 남긴다.

### macOS / Docker Desktop 주의점

Docker Desktop은 Linux VM 안에서 engine이 돌아간다. 그래서 host(macOS)에서 보는 경로와 engine 내부 경로가 다를 수 있다.

| 증상 | 원인/포인트 |
|---|---|
| `date +%s%N`이 안 됨 | macOS는 BSD `date`. 나노초·`-v` 옵션이 GNU와 다름 |
| `mkdir /var/lib/docker: read-only file system` | `host-mount` profile에서 Docker data root를 못 만듦. 기본 실행으로 돌아가고 cAdvisor/Promtail은 선택 처리 |
| Promtail/Loki log가 비어 있음 | host-mount가 안 돼 수집이 안 된 것. Docker Desktop VM 내부 log 경로와 host 경로가 다름 |
| cAdvisor device/mount 오류 | Docker Desktop VM의 장치 mount 제약. **실패 자체를 runtime 차이 관찰 사례로** 다룸 |
| Grafana에서 Prometheus 연결 실패 / `connection refused` | datasource URL을 `localhost:19090`이 아니라 `http://prometheus:9090`으로 저장 (위 "포트 두 세계" 참고) |
| `port is already allocated` | 다른 container가 host port 점유. `docker ps`로 충돌 port 확인 |

(preview 성공 기준은 위 "선택 심화" 섹션 표 참고 — 기본 스택만 떠도 성공, cAdvisor/Promtail 실패는 환경 차이로 남긴다.)

### Cleanup

```bash
docker compose down       # container/network 정리 (dashboard·log data는 유지)
# docker compose down -v   # dashboard/log data까지 reset할 때만
```

`down -v`는 Grafana 설정·Loki log data까지 지운다 — 6·7교시의 volume 삭제 판단과 동일하다. 참고로 datasource URL을 `localhost:19090`으로 잘못 저장해버렸다면 보통 **Grafana UI에서 `http://prometheus:9090`으로 고치는 게 우선**이고, 실습 data를 버려도 될 때만 `down -v`로 `grafana-data` volume을 초기화한다.

#### `down`이 "Resource is still in use"로 막힐 때 — profile을 같이 내린다

`docker compose down`은 **기본(default) 서비스만** 내린다. `--profile`로 띄운 cpu-spike(`load`), cadvisor·promtail(`host-mount`)은 그대로 남아 network에 붙어있어, network를 못 지우고 `Resource is still in use`가 난다.

```bash
# up에 줬던 profile을 down에도 똑같이 준다
docker compose --profile load --profile host-mount down
```

`docker compose down --remove-orphans`로는 보통 안 된다. orphan은 "compose 설정에 **아예 없는**" 컨테이너인데, profile 컨테이너는 설정에 **있고 profile로 묶여있을 뿐**이라 orphan이 아니기 때문이다. 핵심: **profile로 띄웠으면 내릴 때도 같은 profile을 명시한다.**

### 핵심 포인트

Day 4의 마지막 목표는 **dashboard를 잘 꾸미는 것이 아니다.** 단일 container 명령으로 보던 증거(`logs`/`stats`)가 Compose와 observability stack에서 metrics/logs로 확장된다는 감각을 잡는 것이다. dashboard가 있어도 원인은 결국 command/output을 같이 봐야 좁혀진다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| 강사님 대시보드 패널이 전부 No data (cadvisor/promtail은 `Up`, 로그도 나옴) | Prometheus에서 `container_cpu_usage_seconds_total` 직접 query → 라벨이 `cpu/id/instance/job`뿐이고 `name`·`container_label_com_docker_compose_*`가 없음. 강사님 쿼리의 `name!=""`·compose 라벨 필터에 다 걸러진 것. macOS Docker Desktop은 cAdvisor가 컨테이너 메타데이터(이름·라벨)에 못 닿아 cgroup `id`까지만 붙음 → 환경 차이로 판단, `id=~"/docker/.+"` 쿼리로 대체 가능 (notes "강사님 대시보드 쿼리…" 참고) |
| `docker compose down`이 `Network ... Resource is still in use`로 막힘 | `--profile`로 띄운 cpu-spike/cadvisor/promtail이 안 내려가 network에 남음. `--profile load --profile host-mount down`으로 같은 profile 명시해서 해결 (`--remove-orphans`는 profile 컨테이너엔 안 먹음) |
| Grafana datasource `connection refused` (`localhost:19090`) | Grafana 컨테이너 입장의 `localhost`는 자기 자신. datasource는 `http://prometheus:9090`(서비스 이름+내부 포트)이어야 함. provisioning이 원래 그렇게 박아둠 |
