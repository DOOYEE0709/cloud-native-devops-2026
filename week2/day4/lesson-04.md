# 4교시: Stats, resource, restart policy

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker stats paperclip-day4-nginx --no-stream` | CPU %, MEM USAGE / LIMIT 등 resource snapshot 확인 |
| `docker inspect paperclip-day4-nginx --format 'before={{json .HostConfig.RestartPolicy}}'` | `before={"Name":"no","MaximumRetryCount":0}` — 초기 restart policy 미설정 |
| `docker update --restart unless-stopped paperclip-day4-nginx` | 실행 중 container의 restart policy 변경 |
| `docker inspect ... 'after={{json .HostConfig.RestartPolicy}}'` | `after={"Name":"unless-stopped",...}` — 변경 반영 확인 |
| `docker run -d --name paperclip-day4-crash --restart on-failure:3 alpine:3.20 sh -c 'echo crash-now; exit 1'` | 일부러 실패하는 container로 crash loop 재현 |
| `docker logs paperclip-day4-crash` | `crash-now`가 반복 출력 (재시작마다 같은 줄) |
| `docker inspect paperclip-day4-crash --format 'RestartCount={{.RestartCount}} ... ExitCode={{.State.ExitCode}}'` | `RestartCount=3`, `ExitCode=1` — 3회 재시도 후 멈춤 |
| `docker run -d --name paperclip-day4-restart-missing-env --restart on-failure:2 postgres:16-alpine` | 필수 env 없이 postgres 실행 (의도된 실패) |
| `docker inspect ... 'RestartCount=... ExitCode=...'` | `RestartCount=2` — restart로도 못 살아남음 |
| `docker logs paperclip-day4-restart-missing-env --tail 20` | `POSTGRES_PASSWORD` 누락 에러 반복 — config 문제는 restart로 안 풀림 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| `docker stats`는 무엇을 보는가? | container의 CPU, memory, network, block I/O 사용량을 본다. `--no-stream`은 실시간 갱신 없이 한 번의 snapshot만 찍는다. Day 4에서는 성능 튜닝이 아니라 "resource를 쓰고 있는지, 비정상 재시작 중인지" 관찰 입구로 쓴다. |
| restart policy는 무엇을 해주고 무엇을 못 해주는가? | process가 죽었을 때 다시 시작해준다. 하지만 설정 누락·잘못된 command·port 충돌 같은 **원인은 고치지 못한다.** 원인이 그대로면 재시작해도 또 죽는다. |
| restart policy 종류는? | `no`(기본, 재시작 안 함), `on-failure[:N]`(0이 아닌 exit code일 때만, 최대 N회), `always`(항상), `unless-stopped`(사용자가 직접 멈춘 경우 빼고 항상). |
| 실행 중인 container의 restart policy를 바꾸려면? | `docker update --restart <policy> <container>`. container를 다시 만들지 않고 정책만 바꿀 수 있다. |
| crash loop가 뭔가? | container가 죽고 → restart policy가 다시 띄우고 → 또 죽는 것이 반복되는 상태다. `RestartCount` 증가와 logs에 같은 에러 줄 반복으로 확인한다. |
| postgres가 계속 죽은 이유는? | `POSTGRES_PASSWORD` 같은 필수 env가 없어서다. restart를 2번 해도 env가 그대로 없으니 계속 실패한다. 해결은 restart 횟수 조정이 아니라 missing env 주입이다. |
| resource 수치가 높으면 바로 restart policy를 바꿔야 하나? | 아니다. 먼저 logs로 error를 보고, inspect로 RestartCount·ExitCode를 확인하고, 필요하면 exec로 내부를 본다. "많이 재시작한다"가 아니라 "왜 재시작하는지 증거를 모은다"가 기준이다. |

## notes

### docker stats — resource 관찰의 입구

`docker stats`는 container의 CPU, memory, network, block I/O를 보여준다. Day 4는 성능 튜닝을 깊게 하지 않고, **실행 중 container가 resource를 쓰는지, 비정상 재시작 중인지**를 관찰하는 출발점으로만 쓴다.

| 출력 | 의미 |
|---|---|
| `CPU %` | container가 쓰는 CPU 비율 |
| `MEM USAGE / LIMIT` | 사용 메모리 / 한도 |
| `NET I/O`, `BLOCK I/O` | 네트워크·디스크 입출력 |

`--no-stream`은 실시간 갱신 화면 대신 **한 번의 snapshot**만 찍어 스크립트·기록에 쓰기 좋다.

### restart policy — 재시작은 하지만 원인은 못 고친다

restart policy는 container process가 죽었을 때 다시 시작할지 정하는 정책이다. **원인(설정 누락, 잘못된 command, port 충돌)은 고치지 않는다.** 원인이 그대로면 재시작해도 또 죽는다.

| 정책 | 동작 |
|---|---|
| `no` (기본) | 죽어도 재시작 안 함 |
| `on-failure[:N]` | exit code가 0이 아닐 때만, 최대 N회 재시작 |
| `always` | 어떤 이유로 죽든 항상 재시작 |
| `unless-stopped` | 사용자가 직접 멈춘 경우를 빼고 항상 재시작 |

실행 중인 container의 정책은 `docker update --restart <policy> <container>`로 바꾼다.

### crash loop — 증상 완화 ≠ 원인 해결

required env가 없어 바로 죽는 container에 `--restart on-failure`를 붙이면 **반복 재시작(crash loop)** 이 된다. 이때 해결은 restart 횟수를 늘리는 게 아니라 **missing env를 고치는 것**이다. 반복 재시작은 오히려 장애를 숨길 수 있어 logs와 함께 봐야 한다.

| 출력 | 해석 |
|---|---|
| `RestartCount` 증가 | process가 반복 실패 중 |
| `ExitCode=1` | command가 실패로 종료됨 |
| logs에 같은 줄 반복 | restart가 원인을 해결하지 못하고 있음 |
| `POSTGRES_PASSWORD` 반복 | config 누락을 restart로 가리고 있음 |

핵심: postgres 실습이 보여주듯, restart는 `POSTGRES_PASSWORD` 같은 **config 누락을 해결하지 못한다.** 증상(자꾸 죽음)을 완화하려 재시작에 기대지 말고, 원인(env 누락)을 source에서 고친다.

### 실습 명령의 `sleep 3`은 왜 있나

crash loop 실습에서 `docker run -d` 다음에 `sleep 3`이 들어간다. `-d`(detached)는 container 결과를 **기다리지 않고 즉시 다음 줄로 넘어가기** 때문이다. 바로 `inspect`하면 아직 죽지도 재시작하지도 않은 상태를 찍어 `RestartCount=0`이 나온다.

```text
sleep 없이 바로 inspect → RestartCount=0  (반복 실패 증거 안 나옴)
sleep 3으로 시간 확보  → 죽음→재시작→죽음... 진행 → RestartCount=2
```

즉 **crash loop가 실제로 진행될 시간을 벌어주는 것**이다. 단, `sleep`은 실습 편의용 고정 대기다. 실무 스크립트에서는 고정 sleep(너무 짧으면 못 잡고 길면 느림)보다 **원하는 상태가 될 때까지 폴링**하는 방식을 선호한다.

### 진단 순서 — 증거부터 모은다

resource 수치가 높다고 곧바로 restart policy를 바꾸지 않는다.

```text
1. docker logs       → error 메시지 확인
2. docker inspect    → RestartCount, State.Status, ExitCode 확인
3. docker exec       → (필요 시) 내부 상태 확인
4. 원인을 source에서 수정 → container 재생성
```

Day 4 기준은 "많이 재시작한다"가 아니라 **"왜 재시작하는지 증거를 모은다"** 다.

### docker stats의 한계 → metrics observability

`docker stats --no-stream`은 **snapshot**이다. 한 번 보고 끝내면 "CPU가 몇 %였다" 정도만 남는다. 운영의 진짜 질문에는 부족하다.

| 질문 | `docker stats`만으로 부족한 이유 | 다음 단계 |
|---|---|---|
| 언제부터 CPU가 올라갔는가 | 과거 추세가 없다 | Prometheus time series |
| 어떤 container가 계속 증가하는가 | 순간값만 보고 놓칠 수 있다 | Grafana panel / Explore |
| spike 시점에 무슨 log가 있었는가 | metrics에는 log line이 없다 | Loki 또는 `docker logs` |
| 재시작 직전 resource는 어땠는가 | 이전 상태가 사라진다 | metrics retention |

그래서 Day 4 마지막에 Prometheus/Grafana/cAdvisor/Loki를 살짝 본다. 깊게 배우는 게 아니라 **`stats`가 metrics observability로 확장된다는 감각**을 잡는 것이 목적이다.

### 흔한 오해

- restart policy를 붙이면 장애가 해결된다 → 재시작만 할 뿐 원인(env·command·port)은 그대로다.
- 자꾸 죽으면 restart 횟수를 늘리면 된다 → 횟수 조정은 증상 완화. 원인을 source에서 고쳐야 한다.
- `RestartCount`가 0이 아니면 무조건 장애다 → 재시작 자체보다 logs의 반복 에러로 원인이 안 풀렸는지를 본다.
- `docker stats`로 운영 모니터링이 된다 → snapshot일 뿐. 추세·과거·log 상관관계는 metrics 도구가 필요하다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
