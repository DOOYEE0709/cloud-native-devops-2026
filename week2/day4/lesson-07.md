# 7교시: Compose mapping handoff

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| Day 4 `docker run` option들을 Compose 항목으로 매핑 | `-p`→`ports`, `-e`→`environment`, `--env-file`→`env_file`, `-v`→`volumes`, `--network`→`networks` 대응 정리 |
| 관찰 명령을 Compose 명령으로 매핑 | `docker logs`→`docker compose logs`, `docker exec`→`docker compose exec` |
| cleanup을 Compose로 매핑 | `docker rm/network rm`→`docker compose down`, volume 포함은 `down -v` |
| `docker ps -a --filter name=paperclip-day4` | cleanup 후 실습 container가 남지 않음 확인 |
| `docker network ls \| grep paperclip-day4` | 임시 network가 남지 않음 확인 |
| `docker volume ls \| grep paperclip-day4` | volume은 삭제 여부를 의식적으로 판단했는지 확인 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Day 4는 Compose를 배우는 날인가? | 아니다. **Compose가 왜 필요한지 몸으로 느끼는 날**이다. `docker run`에 port·env·volume·network·restart option이 계속 붙어 길고 실수하기 쉬워지는 걸 겪고, 그 조건을 Day 5에서 `compose.yaml`에 남긴다. |
| `-e`와 `--env-file`은 Compose 어디로 가나? | `-e KEY=value`는 `services.<name>.environment`, `--env-file .env`는 `env_file`(또는 `${VARIABLE}`)로 간다. |
| `-p`, `-v`, `--network`는? | 각각 `services.<name>.ports`, `services.<name>.volumes`, 최상위 `networks`로 매핑된다. |
| cleanup은 Compose에서 어떻게 하나? | `docker compose down`으로 container·network를 정리한다. volume까지 지우려면 `down -v`인데, 이건 Day 4의 `volume rm`처럼 **data 삭제** 판단이 필요하다. |
| 이 mapping은 Compose에서 끝나나? | 아니다. `environment`/`env_file`/`volumes`/`networks`는 Kubernetes의 ConfigMap·Secret·Volume·Service로, Terraform의 `*.tfvars`·storage·VPC로 이어진다. 같은 사고가 도구만 바뀌어 확장된다. |
| `docker stats`/`docker logs`는 운영에서 무엇으로 확장되나? | `stats`는 Prometheus+cAdvisor metrics로, `logs`는 Loki+Grafana로 확장된다. 순간 관찰 → 추세·검색 가능한 observability로 넘어간다. |
| Day 4의 완료 기준은? | 명령을 많이 실행한 게 아니라, **실행 조건(runtime config)과 관찰 증거(logs/inspect/stats)를 분리해서 설명할 수 있는 것**이다. |

## notes

### Day 4의 의미 — Compose가 필요한 이유를 몸으로 느끼는 날

Day 4는 Compose를 배우는 날이 아니다. `docker run`에 option이 하나씩 붙으며 명령이 길고 실수하기 쉬워지는 걸 직접 겪는 날이다. 이 불편이 곧 Day 5에서 조건을 `compose.yaml` 파일로 남기는 동기가 된다.

```bash
# Day 4: 길어지는 docker run
docker run -d --name web -p 18084:80 -e APP_ENV=prod --env-file .env \
  -v pgdata:/var/lib/postgresql/data --network net-a --restart unless-stopped nginx:1.27-alpine
```

→ Day 5에서는 이 조건들이 `compose.yaml`의 선언적 항목으로 정리된다.

### docker run option → Compose 매핑

| Day 4에서 사용한 것 | 의미 | Day 5 Compose 위치 |
|---|---|---|
| `docker run -d --name ...` | service process 시작 | `services.<name>` |
| `-p 18084:80` | host/container port publish | `services.<name>.ports` |
| `-e KEY=value` | runtime env 직접 주입 | `services.<name>.environment` |
| `--env-file .env` | env file 사용 | `env_file` 또는 `${VARIABLE}` |
| `.env.dev/.env.staging/.env.prod` | 환경별 설정 파일 | 환경별 Compose project 또는 env file |
| `-v source:target` | mount/volume 연결 | `services.<name>.volumes` |
| `--network name` | network 연결 | `networks` |
| `docker logs` | log 확인 | `docker compose logs` |
| `docker exec` | 내부 명령 실행 | `docker compose exec` |
| cleanup 명령 | 종료/삭제 | `docker compose down`, 필요 시 `down -v` |
| `docker stats` | 순간 resource 관찰 | Prometheus + cAdvisor metrics |
| `docker logs` | 일반 log 확인 | Loki + Grafana Explore |

### 같은 사고가 K8s·Terraform으로 확장된다

| Day 4 개념 | Compose | Kubernetes | Terraform |
|---|---|---|---|
| `-e KEY=value` | `environment` | ConfigMap/Secret env | variable |
| `--env-file .env.dev` | `env_file` | 환경별 ConfigMap/Secret | `dev.tfvars` |
| `-p host:container` | `ports` | Service/Ingress | load balancer/security group |
| `-v volume:/path` | `volumes` | Volume/PVC | storage resource |
| `--network` | `networks` | Service DNS/network policy | VPC/subnet/security group |
| cleanup 판단 | `down` vs `down -v` | delete resource vs preserve PVC | destroy/retain state |
| metrics/logs | Prometheus/Grafana/Loki | metrics-server/Prometheus/Loki | monitoring resources |

핵심: 배우는 건 특정 도구 문법이 아니라 **"실행 조건을 코드로 분리하고, 환경 차이를 설정으로 표현하고, data는 신중히 다룬다"** 는 원칙이다. 도구가 바뀌어도 이 사고는 그대로 이어진다.

### cleanup 판단도 그대로 따라간다

`docker compose down`은 container·network를 정리하지만 volume은 남긴다. `down -v`를 붙여야 volume까지 지운다 — 이건 Day 4의 `docker volume rm`과 같은 **data 삭제 판단**이다. Kubernetes에서도 `delete`는 보통 PVC를 보존하고, 명시적으로 지워야 data가 사라진다. **"down과 down -v의 차이 = 6교시 volume 삭제 판단"** 으로 기억한다.

### Day 4 완료 기준 — 명령 수가 아니라 분리 능력

Day 4의 완료 기준은 명령을 많이 실행한 게 아니다. **실행 조건(runtime config)과 관찰 증거(logs/inspect/stats)를 분리해서 설명할 수 있는 것**이다.

| 분리해야 할 것 | 예시 |
|---|---|
| 실행 조건 (어떻게 띄웠나) | `-e`, `--env-file`, `-p`, `-v`, `--network`, `--restart` |
| 관찰 증거 (어떻게 확인했나) | `docker logs`, `inspect`, `exec`, `stats`, `ps -a` |

같은 image라도 실행 조건이 다르면 동작이 다르고, 정상 여부는 관찰 증거로만 확인된다. 이 둘을 섞지 않는 게 Day 4의 핵심이고, Day 5 Compose는 그 실행 조건을 파일로 옮기는 작업이다.

### 가용성 — AZ와 멀티 리전 (왜 둘 다 두나)

7교시 mapping 표의 `-p host:container` → load balancer 줄에서 이어지는 운영 주제다. 로드 밸런서가 "여러 container에 분배"하는 발상을 더 큰 단위(건물·지역)로 확장한 것이 가용성 설계다.

핵심은 **위협의 크기에 따라 보험을 여러 겹 둔다**는 것이다.

```text
서버 1대 고장      → 같은 AZ 안 다른 서버 (로드 밸런서)
건물/AZ 1곳 다운   → 멀티 AZ (같은 리전, 다른 건물)   ← 흔한 사고 대부분 커버
지역 전체 재해     → 멀티 리전 (다른 도시/국가)        ← 천재지변급, 비쌈
```

| 개념 | 무엇인가 | 막는 사고 | 못 막는 사고 |
|---|---|---|---|
| **AZ** (가용 영역) | 같은 리전 안의 **물리적으로 분리된** 데이터센터 (다른 건물·독립 전력/냉각/네트워크) | AZ 1곳 정전, 하드웨어 고장, 한 건물 화재·침수 | **지역 전체를 덮치는 재해** (대지진 등) |
| **멀티 리전** | 지리적으로 떨어진 다른 지역(도시/국가)에 복제 | 리전 전체 다운, 천재지변, 국가적 재난 | (비용·복제 지연이 대가) |

주의점: AZ는 떨어져 있어도 **같은 지역(수도권 등)** 안이라, 그 지역 전체를 덮치는 재해엔 같이 위험하다. 그래서 멀티 AZ로는 부족한 "리전급 재해"를 멀티 리전이 채운다. 둘은 **역할이 다른 두 겹의 보험**이다(AZ = 흔한 국지 사고, 멀티 리전 = 지역급 재해).

#### 멀티 리전의 비용 트레이드오프

실시간으로 다른 리전에 복제하면 안전하지만 **비용이 크다**. 그래서 무조건 하지 않고 **"복제 비용 vs 다운타임 손실"** 을 저울질한다. 서비스 다운으로 잃는 게 복제 비용보다 크면 복제하고, 아니면 안 한다.

| 지표 | 뜻 |
|---|---|
| **RTO** (Recovery Time Objective) | 장애 후 **얼마 만에** 복구해야 하나 |
| **RPO** (Recovery Point Objective) | 데이터를 **얼마까지** 잃어도 되나 (예: 마지막 5분치) |

RTO/RPO가 0에 가까워야 하는 서비스(결제·금융)는 멀티 리전 실시간 복제를 감수하고, 잠깐 다운돼도 되는 내부 도구는 단일 리전 + 백업으로 둔다. 대부분 서비스는 **멀티 AZ를 기본**으로, 멀티 리전은 그 위의 더 비싼 선택으로 둔다.

### Day 5로 넘길 질문 (handoff)

| 구분 | Day 5로 넘길 질문 |
|---|---|
| env/config | 환경별(`.env.dev/staging/prod`)을 Compose에서 어떻게 분리하나 |
| secret 비노출 | Compose에서 secret을 environment에 평문으로 두지 않으려면 |
| volume | `down`과 `down -v` 중 언제 무엇을 쓰나 (data 보존 판단) |
| network | service 간 name 통신이 Compose에서 어떻게 자동 구성되나 |
| 관찰 | `compose logs`/`compose exec`가 단일 `docker` 명령과 무엇이 다른가 |

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
