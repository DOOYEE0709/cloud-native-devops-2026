# 3교시: Inspect와 exec로 내부 확인

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker inspect paperclip-day4-nginx --format 'Ports={{json .NetworkSettings.Ports}}'` | `80/tcp`가 host `18084`로 publish된 것 확인 (`0.0.0.0`, `::` 둘 다) |
| `docker inspect paperclip-day4-nginx --format 'Image={{.Config.Image}} Restart={{json .HostConfig.RestartPolicy}}'` | `Image=nginx:1.27-alpine`, `Restart={"Name":"no",...}` — restart policy 미설정 확인 |
| `docker exec paperclip-day4-nginx ls -l /usr/share/nginx/html` | container가 실제로 serving하는 파일 목록(`index.html`, `50x.html`) 확인 |
| `docker exec paperclip-day4-nginx sh -c 'ps \| head'` | PID 1 = `nginx: master process`, worker process들 확인 |
| `docker exec paperclip-day4-nginx sh -c 'cat /etc/nginx/conf.d/default.conf \| sed -n "1,40p"'` | `listen 80`, `root /usr/share/nginx/html` 등 실제 설정 내용 확인 |
| `docker run -d --name paperclip-day4-env-inspect --env-file ... alpine:3.20 sleep 300` | env 확인용 container 생성 |
| `docker inspect ... '{{range .Config.Env}}...' \| grep ... \| sed 's/DB_PASSWORD=.*/.../'` | `inspect`로 env 확인하되 `DB_PASSWORD`는 `***masked***`로 기록 |
| `docker exec ... sh -c 'env \| grep ...' \| sed '...masked...'` | `exec env`로도 같은 값 확인 가능, 동일하게 masking 기록 |
| (대조) masking 없이 `docker inspect ... .Config.Env \| grep DB_PASSWORD` | `DB_PASSWORD=change-me-locally` 평문 노출 — inspect도 secret 유출 경로임 확인 |
| `docker exec paperclip-day4-log-env env` (Exited container) | `Error: container ... is not running` — `exec`는 실행 중 container만 가능 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| `inspect`와 `exec`는 무엇이 다른가? | `inspect`는 Docker가 알고 있는 metadata(port, image, network, mount, env, restart policy)를 container **밖에서** 본다. `exec`는 실행 중인 container **안에서** 명령을 실행해 filesystem, process, config 파일 같은 내부 상태를 본다. |
| 둘을 언제 골라 쓰는가? | port mapping·image·restart policy처럼 외부 계약이 궁금하면 `inspect`, nginx가 실제로 어떤 파일을 serving하는지처럼 내부 상태가 궁금하면 `exec`다. 섞어 쓰지 않는다. |
| `inspect`나 `exec env`로 secret을 봐도 되는가? | 문제 해결을 위해 값을 **확인**하는 것은 가능하다. 하지만 제출물·질문 글·README에는 전체 출력 대신 key 이름과 `***masked***`만 남긴다. `--env-file`로 넣은 값도 metadata와 내부 환경 양쪽에서 보인다. |
| logs에서 masking했으면 inspect는 안전한가? | 아니다. `docker inspect`의 `Config.Env`에는 `DB_PASSWORD`가 평문으로 그대로 남는다. masking은 출력·문서 기준이지, inspect로 막히는 게 아니다. inspect도 유출 경로다. |
| `exec`로 멈춘(Exited) container 안에 들어갈 수 있는가? | 없다. `exec`는 실행 중인 process가 있어야 그 안에서 명령을 실행한다. 멈춘 container는 `Error: container is not running`이 난다. 상태·설정을 보려면 `inspect`나 `docker ps -a`를 쓴다. |
| `exec -it ... sh`로 들어가서 파일을 고쳐도 되는가? | 안 된다. shell은 확인 도구이지 배포 도구가 아니다. container 내부를 손으로 고치면 image·Dockerfile·compose·Git 어디에도 변경 근거가 남지 않아 재현 불가능한 장애가 된다. 수정이 필요하면 빠져나와 Dockerfile/env file/volume/run option에서 바꾸고 container를 다시 만든다. |
| `inspect` 전체 JSON을 그대로 기록해도 되는가? | 안 된다. 전체를 붙이면 읽기 어렵고 secret까지 노출된다. `--format`으로 문제와 관련된 field만 뽑아 증거로 남긴다. |

## notes

### inspect와 exec의 역할 구분

| 명령 | 보는 위치 | 보는 것 | 멈춘 container |
|---|---|---|---|
| `docker inspect` | container **밖** (Docker metadata) | port, image, network, mount, env, restart policy, State/ExitCode | 가능 (정지해도 metadata 존재) |
| `docker exec` | container **안** (실행 중 프로세스) | filesystem, process, config 파일, 내부 tool 존재 여부 | 불가 (실행 중이어야 함) |

핵심: **port mapping이 궁금하면 `inspect`, nginx가 실제로 어떤 파일을 serving하는지 궁금하면 `exec`.** 두 명령을 섞어 쓰지 않는다.

### inspect는 `--format`으로 필요한 field만

`docker inspect` 전체 JSON은 길고 secret까지 포함한다. 문제와 관련된 field만 뽑아 증거로 남긴다.

| 알고 싶은 것 | format 경로 |
|---|---|
| host port 연결 | `{{json .NetworkSettings.Ports}}` |
| 어떤 image로 떴는가 | `{{.Config.Image}}` |
| restart policy | `{{json .HostConfig.RestartPolicy}}` |
| env 적용 여부 | `{{range .Config.Env}}{{println .}}{{end}}` |
| 상태/exit code | `{{.State.Status}}` `{{.State.ExitCode}}` |

### exec shell 운영 원칙 — 진단 도구이지 배포 도구가 아니다

shell은 관찰을 편하게 해주지만 동시에 내부를 임의로 바꿀 수 있는 통로다. 손으로 고친 container는 `docker inspect`·Git·Dockerfile 어디에도 근거가 안 남아, 같은 image로 다시 띄우면 장애가 재현되거나 현재 container만 우연히 정상인 상태가 된다.

| 허용 (상태 확인) | 금지 (내부 변경) |
|---|---|
| `ls`, `pwd`, `cat`, `head`, `tail`, `find`, `ps`, `env`, `whoami` | `vi`, `nano`, `sed -i`, `rm`, `mv`, `cp` |
| config·static 파일, process, env key 존재 여부 확인 | `apk add`, `apt install`로 package 설치 |
| 확인 내용을 README/runbook에 evidence로 기록 | container 안에서 hotfix하고 정상이라 보고 |
| 수정 필요 시 Dockerfile/env/volume/run option으로 되돌아가 변경 | 운영 container를 snowflake server처럼 손으로 관리 |

container 내부를 바꿔야 문제가 풀린다면, 그 변경은 container 안이 아니라 image build, runtime config, mounted file, `compose.yaml`처럼 **재현 가능한 위치**에 반영한다.

#### snowflake server를 만들지 않는다

**snowflake server**는 눈송이처럼 그 서버만의 고유한 상태를 가진, 똑같이 재현할 수 없는 서버를 말한다. 누군가 `exec`로 들어가 `apk add`로 패키지를 깔고 `vi`로 설정을 고치고 `rm`으로 파일을 지운 변경이 Dockerfile·compose·Git 어디에도 안 남으면, 그 container는 snowflake가 된다.

snowflake는 자동 관리가 힘들다 — 맞다. 이유는 다음과 같다.

| 문제 | 왜 자동화가 안 되나 |
|---|---|
| 재현 불가 | 손으로 한 변경이 코드에 없어서, 같은 image로 다시 띄우면 그 상태가 안 나온다 |
| 추적 불가 | 누가 언제 뭘 바꿨는지 근거가 Git/inspect에 안 남는다 |
| 대체 불가 | 서버가 죽으면 똑같은 걸 다시 만들 방법이 없다 — 그 서버가 유일본 |
| 자동화 도구가 모름 | Ansible/Terraform/CI·CD는 **코드에 적힌 상태**만 적용한다. 손으로 한 변경은 인식 못 하고, 자동 배포가 오히려 그 변경을 덮어써 장애가 난다 |

반대 개념은 **phoenix server**다. 불사조처럼 언제든 죽여서 똑같이 다시 살릴 수 있는 서버 — 모든 상태가 코드(Dockerfile, compose, IaC)에 있기 때문이다. "cattle, not pets(애완동물이 아니라 가축처럼)"도 같은 뜻이다.

```text
snowflake : 손으로 키운 유일한 서버, 죽으면 끝       (지양)
phoenix   : 코드로 언제든 재생성, 죽여도 똑같이 부활  (지향)
```

`exec`로 안에서 고치지 말고 Dockerfile/env/volume으로 돌아가라는 원칙이, 곧 container를 snowflake로 만들지 않기 위한 것이다.

### inspect / exec env는 secret을 보여준다 — masking이 필요하다

`inspect`와 `exec env` 모두 값 확인이 가능하다. 그래서 문제 해결에는 유용하지만, 기록에는 masking이 필요하다.

```bash
docker inspect paperclip-day4-env-inspect --format '{{range .Config.Env}}{{println .}}{{end}}' \
  | grep -E 'APP_ENV|FEATURE_FLAG|DB_PASSWORD' \
  | sed -E 's/DB_PASSWORD=.*/DB_PASSWORD=***masked***/'
```

```text
APP_ENV=practice
FEATURE_FLAG=on
DB_PASSWORD=***masked***
```

| 출력 | 판단 |
|---|---|
| `APP_ENV=practice` | 환경 이름, 기록 가능 |
| `FEATURE_FLAG=on` | 기능 플래그, 기록 가능 |
| `DB_PASSWORD=***masked***` | masking 후 기록 |
| `DB_PASSWORD=change-me-locally` (masking 전) | 실패, secret 평문 노출 |

핵심: masking은 출력·문서 기준이다. `inspect`의 `Config.Env`에는 평문이 그대로 남으므로, **inspect/logs 모두 secret 유출 경로**라는 감각을 갖는다. 이미 노출된 credential은 masking이 아니라 revoke/rotate가 답이다(1교시 연결).

#### masking은 env가 많아지면 확장이 안 된다

`sed 's/DB_PASSWORD=.*/.../'` 방식은 "위험한 걸 골라서 가리는" **denylist**다. env가 수십~수백 개가 되면 어떤 게 secret이고 아닌지 매번 사람이 판단해야 하고, 새 secret key가 추가됐는데 규칙을 안 고치면 그대로 평문 노출된다. denylist는 본질적으로 **하나만 빠뜨려도 사고**가 나는 구조라 확장되지 않는다.

그래서 현업의 답은 출력 시점에 가리는 게 아니라 두 갈래다.

| 전략 | 내용 |
|---|---|
| ① secret을 처음부터 분리 | config(노출돼도 되는 값)와 secret을 **저장 시점**에 나눈다. `APP_ENV`·`FEATURE_FLAG` 같은 config는 ConfigMap/평범한 env로, `DB_PASSWORD`·API key·cloud key 같은 secret은 Secret Manager/Vault/K8s Secret에 두고 앱이 런타임에 가져온다. secret이 애초에 로그·출력 경로에 없으니 masking 고민이 사라진다. |
| ② 노출돼도 되는 건 그냥 넘긴다 | `APP_ENV=prod`, `FEATURE_FLAG=on`처럼 노출돼도 피해가 없는 값은 가리려 애쓰지 않는다. 가리는 것 자체가 낭비다. |

규모가 커지면 로깅도 방향을 뒤집어 **allowlist**로 간다.

| 방식 | 규칙 | 위험 |
|---|---|---|
| denylist (masking) | "이것들을 가려라" | 빠뜨린 secret이 노출됨 |
| **allowlist** | "이 안전한 것들만 찍어라" | 모르는 새 key는 기본적으로 안 찍힘 → 사고 안 남 |

정리: **masking은 env가 적은 로컬 실습 수준의 임시 방편**이지 운영 전략이 아니다. 운영에서는 secret을 외부에서 관리해 출력 경로에 두지 않고, 노출돼도 되는 값만 통과시키는 구조로 간다([[`.env`는 로컬 개발 패턴이다]] · 2교시 "masking해도 위험하다"와 같은 결론).

### 짧은 명령 vs interactive shell

| 상황 | 방식 |
|---|---|
| 한 가지를 빠르게 확인 | `docker exec <container> <command>` |
| 여러 파일을 이어서 확인 | `docker exec -it <container> sh`로 진입 후 read-only 명령만 |

interactive shell에서도 `vi`, `rm`, `apk add`는 실행하지 않는다. 실습 container라도 그 습관이 운영 환경에서 사고가 된다.

### 판단 drill

| 상황 | 먼저 볼 증거 | 이유 |
|---|---|---|
| host port가 열렸는지 모르겠다 | `inspect ... NetworkSettings.Ports` | Docker가 적용한 publish 정보를 본다 |
| 어떤 image로 떴는지 모르겠다 | `inspect ... Config.Image` | 외부 계약(어떤 artifact로 떴는가)을 본다 |
| restart policy가 무엇인지 모르겠다 | `inspect ... HostConfig.RestartPolicy` | 재시작 동작 설정을 본다 |
| nginx가 어떤 파일을 serving하는지 모르겠다 | `exec ... ls /usr/share/nginx/html` | container 내부 filesystem을 본다 |
| nginx가 어떤 root를 보는지 모르겠다 | `exec ... cat /etc/nginx/conf.d/default.conf` | 설정 파일을 읽기만 한다 |
| process가 무엇인지/죽었는지 모르겠다 | `exec ... ps` 또는 `inspect ... State` / `docker ps -a` | 실행 중이면 `exec ps`, 멈췄으면 `inspect State`로 exit code |
| env가 들어갔는지 확인해야 한다 | `inspect ... Config.Env` 또는 `exec env` + masking | 값 확인은 가능하되 기록은 masking |
| 내부 파일을 고치면 빨리 해결될 것 같다 | 수정 금지, 재현 가능한 source로 | 손수 고친 container는 재배포 시 사라지고 추적을 어렵게 한다 |

### 단일 container port → 운영의 로드 밸런서(ELB/ALB)

실습에서는 `-p 18084:80`으로 container 하나를 host port에 직접 연결하고, `inspect ... NetworkSettings.Ports`로 그 매핑을 확인했다. 운영에서는 같은 container를 **여러 개** 띄우고 그 앞에 로드 밸런서를 둔다. 사용자는 container IP가 아니라 로드 밸런서 주소로 접속하고, 로드 밸런서가 살아있는 container 중 하나로 요청을 분배한다.

```text
실습:   사용자 → host:18084 → container 1개

운영:                      ┌─→ container 1
       사용자 → [ELB/ALB] ─┼─→ container 2
                          └─→ container 3
```

**ELB(Elastic Load Balancing)** 는 AWS의 로드 밸런싱 서비스 전체를 가리키는 우산 이름이고, 그 안에 동작 계층이 다른 종류가 있다.

| 종류 | 동작 계층 | 언제 쓰나 |
|---|---|---|
| **ALB** (Application LB) | L7 (HTTP/HTTPS) | 웹 서비스. URL 경로·도메인 기반 라우팅, HTTPS 종료, health check |
| **NLB** (Network LB) | L4 (TCP/UDP) | 초고성능·저지연. 단순 포트 전달 |
| **GLB** (Gateway LB) | L3 | 방화벽 등 보안 어플라이언스 앞단 |
| **CLB** (Classic LB) | L4/L7 | 구버전, 신규는 잘 안 씀 |

ALB가 L7이라서 가능한 것:

- `/api`는 backend로, `/`는 frontend로 — **경로 기반 라우팅** (2교시 frontend/backend 분리와 같은 구조)
- `shop.example.com`·`blog.example.com`을 한 ALB로 — **도메인 기반 라우팅**
- HTTPS 인증서 처리(SSL termination)
- **health check** — 죽은 container는 자동으로 분배 대상에서 제외 (`docker ps`의 `Up`이 아니라 실제 응답으로 판단하는 2교시 기준과 동일한 발상)

"Elastic(탄력적)"은 트래픽에 따라 처리 용량이 자동으로 늘었다 줄었다 한다는 의미다. 핵심은 **단일 container 직접 연결은 로컬 실습 패턴이고, 운영은 로드 밸런서 뒤에 여러 container를 두는 구조**라는 점이다. Kubernetes에서는 Service/Ingress가 비슷한 역할을 한다.

### Kubernetes로 이어지는 기준

같은 원칙이 Kubernetes에서도 이어진다. Pod의 env, ConfigMap, Secret mount를 `kubectl describe`/`exec`로 확인할 수는 있지만, 민감한 값을 그대로 issue나 README에 붙이면 안 된다. "확인은 하되 변경은 재현 가능한 위치에, secret은 masking"이라는 기준은 도구가 바뀌어도 동일하다.

### 흔한 오해

- `inspect`와 `exec`는 비슷하다 → 보는 위치가 다르다. `inspect`는 밖(metadata), `exec`는 안(실행 중 상태).
- logs에서 masking했으니 안전하다 → `inspect Config.Env`엔 평문이 남는다.
- `exec`로 멈춘 container도 들어갈 수 있다 → 실행 중이어야 한다. 멈춘 건 `inspect`/`ps -a`.
- 실습 container니 안에서 고쳐도 된다 → 습관이 운영 사고가 된다. 변경은 Dockerfile/env/volume/compose로.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
