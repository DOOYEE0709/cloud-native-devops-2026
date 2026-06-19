# 6교시: Failure drill - 실패 출력으로 원인 찾기

## 실습 확인 기록

### 실패 1: Missing file (build 단계)

| 명령 | 설명 | 결과 |
|---|---|---|
| `rm -f week2/day3/labs/static-site-broken/index.html` | index.html 제거해 고의로 실패 조건 만들기 | |
| `docker build -t paperclip-static-site:broken .` | 파일 없는 상태에서 build 시도 | ![build-broken](assets\lesson-06\build-broken.png) |
| `ls -la` / `find . -maxdepth 1 -type f \| sort` | build context 파일 목록 확인 | ![find-files](assets\lesson-06\find-files.png) |
| 복구: `docker build -t paperclip-static-site:broken-fixed .` | index.html 복구 후 재build | ![build-broken-fixed](assets\lesson-06\build-broken-fixed.png) |

### 실패 2: Wrong port (verify 단계)

| 명령 | 설명 | 결과 |
|---|---|---|
| `docker run -d --name paperclip-day3-static-wrong -p 18084:8080 paperclip-static-site:day3` | 잘못된 container port(8080)로 실행 | ![run-wrong-port](assets\lesson-06\run-wrong-port.png) |
| `docker ps -a --filter name=paperclip-day3-static-wrong` | PORTS 컬럼 확인 | ![ps-wrong-port](assets\lesson-06\ps-wrong-port.png) |
| `curl -I http://localhost:18084` | HTTP 응답 확인 (실패 기대) | ![curl-wrong-port-fail](assets\lesson-06\curl-wrong-port-fail.png) |
| 복구: `docker run -d --name paperclip-day3-static-fixed -p 18084:80 paperclip-static-site:day3` | 올바른 container port(80)로 재실행 | ![run-fixed-port](assets\lesson-06\run-fixed-port.png) |
| `curl -I http://localhost:18084` | HTTP 응답 확인 (성공 기대) | ![curl-fixed-port](assets\lesson-06\curl-fixed-port.png) |

### 실패 3: Wrong CMD (run 단계)

| 명령 | 설명 | 결과 |
|---|---|---|
| `docker build -f Dockerfile.bad-cmd -t paperclip-static-site:bad-cmd .` | CMD를 `nginx-bad-command`로 바꾼 Dockerfile로 build | ![build-bad-cmd](assets\lesson-06\build-bad-cmd.png) |
| `docker run -d --name paperclip-day3-bad-cmd paperclip-static-site:bad-cmd` → `docker ps -a --filter name=paperclip-day3-bad-cmd` → `docker logs paperclip-day3-bad-cmd --tail 30` | 실행 시도 → Exited 확인 → 실패 로그 확인 | ![run-ps-logs-bad-cmd](assets\lesson-06\run-ps-logs-bad-cmd.png) |
| `docker image inspect paperclip-static-site:bad-cmd --format "{{json .Config.Cmd}}"` | image에 설정된 CMD 확인 | ![inspect-bad-cmd](assets\lesson-06\inspect-bad-cmd.png) |

### 실패 4: Bloated context (build hygiene)

| 명령 | 설명 | 결과 |
|---|---|---|
| `mkdir -p node_modules __pycache__ dist build coverage tmp` | 불필요 directory 생성 | X |
| `printf "DO_NOT_COMMIT_TOKEN=example" > .env` | secret 파일 생성 | X |
| `du -sh .` | build context 전체 크기 확인 | X |
| `find . -maxdepth 2 -type f \| sort` | context 안 파일 목록 확인 | ![find-bloated](assets\lesson-06\find-bloated.png) |
| `sed -n '1,160p' .dockerignore` | .dockerignore 패턴 확인 | ![dockerignore](assets\lesson-06\dockerignore.png) |
| 복구: `rm -rf .env node_modules __pycache__ dist build coverage tmp` | 생성한 파일 정리 | X |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 실패 분석의 첫 질문은 무엇인가? | "어느 단계까지 성공했는가"다. build / run / verify로 먼저 나눠야 원인을 찾는 방향이 생긴다. |
| `COPY ... not found` 에러가 나면 어디를 먼저 보는가? | build context 경로와 Dockerfile의 source path다. 파일이 context 밖에 있거나 파일명이 다르면 이 에러가 난다. |
| container가 `Exited`로 표시되면 어디를 보는가? | `docker logs`를 먼저 본다. `executable file not found`가 보이면 CMD/ENTRYPOINT 문제다. |
| `curl` 실패가 port 문제인지 어떻게 확인하는가? | `docker ps`의 PORTS 컬럼과 Dockerfile의 `EXPOSE` 값을 비교한다. `18084->8080/tcp`인데 nginx가 `EXPOSE 80`이면 container port가 틀린 것이다. |
| bloated context는 왜 위험한가? | `.env`처럼 secret이 있는 파일이 build context에 있으면 `COPY . .` 한 줄로 image에 들어간다. push하면 secret이 외부에 노출된다. |
| `Exited (127)`의 의미는? | 127은 command not found exit code다. CMD나 ENTRYPOINT에 지정한 실행파일이 image 안의 `$PATH`에 없다는 뜻이다. |
| 에러 메시지를 외워야 하는가? | 아니다. `COPY`, `not found`, `PORTS`, `Exited`, `connection refused`, `Empty reply` 같은 키워드를 찾으면 어느 단계를 봐야 할지 좁힐 수 있다. |

## notes

### RCA 표

| 실패 유형 | 단계 | 대표 출력 | 첫 확인 명령 | 수정 방향 |
|---|---|---|---|---|
| missing file | build | `COPY ... not found` | `ls`, `Dockerfile`, `find` | source path/context 복구 |
| wrong CMD | run | `Exited`, `executable file not found` | `docker logs`, `inspect .Config.Cmd` | start command 수정 |
| wrong port | verify | `curl failed`, `18084->8080/tcp` | `docker ps`, Dockerfile `EXPOSE` | container port 기준으로 publish 수정 |
| bloated context | build hygiene | `.env`, `node_modules`, 큰 `du -sh` | `.dockerignore`, `find`, `du` | 제외 규칙 추가/정리 |

### 에러별 힌트 키워드

#### Missing file
```text
=> ERROR [3/4] COPY index.html ./index.html
"/index.html": not found
```
→ `COPY` 단계에서 source file이 build context 안에 없음. `ls`로 파일 존재 확인

#### Wrong CMD
```text
STATUS: Exited (127)
docker logs: exec: "nginx-bad-command": executable file not found in $PATH
```
→ container process가 시작 직후 종료됨. `docker logs`와 `inspect .Config.Cmd`로 CMD 확인

#### Wrong port
```text
curl: (52) Empty reply from server   -- 또는
curl: (56) Recv failure: Connection reset by peer   -- 또는
curl: (7) Failed to connect to localhost port 18084
docker ps PORTS: 0.0.0.0:18084->8080/tcp
```

curl 에러 코드는 OS와 Docker 버전에 따라 다르게 나오지만 원인은 동일하다.

| curl 코드 | 의미 | 왜 나오는가 |
|---|---|---|
| `(7)` | connect 자체 실패 | host port가 아예 열려 있지 않을 때 |
| `(52)` | 연결은 됐지만 응답 없음 | 연결은 맺혔지만 서버가 아무것도 안 보냄 |
| `(56)` | 연결 후 peer가 RST로 끊음 | 연결은 맺혔지만 서버가 즉시 거부 |

어떤 코드가 나오든 진단 방법은 같다. `docker ps`의 PORTS 컬럼에서 `18084->8080/tcp`를 보고 container port가 틀렸다고 판단한다. nginx는 container 내부 `80`을 listen하므로 Dockerfile의 `EXPOSE` 기준으로 container port를 맞춰야 한다.

#### Bloated context
```text
.env  →  secret 포함 위험
node_modules/  →  context 크기, OS 의존성 위험
dist/, build/  →  의도하지 않은 build output 포함
```
→ `.dockerignore`에 해당 패턴이 빠져 있으면 image에 들어가거나 build가 느려짐

### 실패 분석 흐름

```text
"Docker가 안 돼요"
    ↓
마지막으로 성공한 단계가 어디인가?
    ├── build 실패  → Dockerfile, build context (파일 경로, .dockerignore)
    ├── run 실패    → image tag, container name, CMD, docker logs
    └── verify 실패 → host port, container port mapping, app port
```

### Exited exit code 해석

| exit code | 의미 |
|---|---|
| `Exited (0)` | 정상 종료 (foreground process가 할 일을 마침) |
| `Exited (1)` | 일반 오류 (app이 스스로 에러로 종료) |
| `Exited (127)` | command not found — CMD/ENTRYPOINT가 image 안에 없음 |
| `Exited (137)` | SIGKILL — OOM kill이나 `docker kill` |

### CMD 결정 우선순위

CMD는 세 곳 중 하나에서 결정된다.

| 순서 | 출처 | 예시 |
|---|---|---|
| 1 | base image에 이미 설정됨 | `nginx` image → `CMD ["nginx", "-g", "daemon off;"]` |
| 2 | 내 Dockerfile에서 직접 지정 | `CMD ["python", "app.py"]` |
| 3 | `docker run` 뒤에 붙이면 덮어씀 | `docker run nginx echo "hello"` |

현재 image에 설정된 CMD 확인:
```bash
docker image inspect <image명> --format "{{json .Config.Cmd}}"
```

### CMD vs ENTRYPOINT

| | CMD | ENTRYPOINT |
|---|---|---|
| 역할 | 기본 명령 (덮어쓰기 가능) | 고정 실행파일 |
| `docker run` 시 덮어쓰기 | 가능 | 불가 (인자만 추가됨) |
| 주로 쓰는 경우 | 기본값 제공 | 항상 같은 프로그램을 실행해야 할 때 |

### 핵심 포인트

실패 분석은 두 단계로 좁힌다.

1. **어느 단계까지 성공했는가** — build / run / verify
2. **출력에서 어떤 힌트를 찾았는가** — 에러 키워드로 확인 방향 결정

에러 문구를 통째로 외울 필요 없다. `COPY`, `not found`, `Exited`, `PORTS`, `connection refused`, `Empty reply` 같은 단어가 보이면 어느 단계 어느 파일을 봐야 할지 좁혀진다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
