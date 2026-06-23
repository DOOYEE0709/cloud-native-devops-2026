# 5교시: Nginx reverse proxy + multiple web services template

> 실습 검증은 lab `week2/day5/labs/compose-architectures/04-nginx-reverse-proxy`(nginx proxy + web-a + web-b, 셋 다 nginx 이미지)로 진행했다.

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker compose config --services` | service 3개 — `web-a`, `web-b`, `proxy` |
| `docker compose up -d` | network 2개(`public_net`/`app_net`) 생성. `web-a`/`web-b` 먼저, `proxy`가 뒤에 기동 |
| `docker compose ps` | `proxy`만 `0.0.0.0:18089->80` 공개. `web-a`/`web-b`는 내부 `80/tcp`만 (host port 없음) |
| `curl -s http://localhost:18089/a/` | `<h1>Web A</h1>` — proxy가 `/a/`를 `web-a`로 routing |
| `curl -s http://localhost:18089/b/` | `<h1>Web B</h1>` — proxy가 `/b/`를 `web-b`로 routing |
| `curl http://localhost:80/a/` (host 직접) | **접근 불가** — web-a는 host에 포트를 안 열어 proxy 통하지 않으면 못 닿음 |
| `curl http://localhost:18089/` (정의 안 된 path) | **HTTP 404** — nginx에 `location /`도 root도 없어서. proxy log에 `"/etc/nginx/html/index.html" is not found` |
| **`docker compose stop web-b`** 후 `/b/` | **HTTP 504** (Gateway Timeout) — proxy가 죽은 upstream 연결을 기다리다 timeout |
| 같은 상태에서 `/a/` | **HTTP 200** + `<h1>Web A</h1>` — web-a는 영향 없음 |
| `docker compose logs proxy` | `upstream timed out (110: Operation timed out) while connecting to upstream ... "GET /b/" ... upstream: "http://172.22.0.2:80/"` |
| `docker compose up -d web-b` 후 `/b/` | **HTTP 200** 복구 |
| `docker compose down` | container 3개·network 2개 정리 (volume 없음) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 이 template은 무엇을 보여주나? | 여러 web service를 **하나의 entrypoint(proxy) 뒤에 숨기고 path로 routing**하는 가장 단순한 reverse proxy 구조. Week 3 MSA의 gateway/API gateway로 가기 직전 단계다. |
| 3교시 gateway와 뭐가 다른가? | 3교시는 gateway가 **정적 페이지 + 여러 business API**(identity/payment)를 routing했다. 5교시는 정적 페이지 없이 **순수 reverse proxy**로 두 web upstream만 가른다. 그래서 `/`(정의 안 된 path)는 3교시처럼 정적 페이지가 아니라 **404**가 난다. |
| `web-a`/`web-b`에 `ports`가 없는 이유는? | 외부 traffic은 **proxy로만** 들어와야 하기 때문. upstream은 host에 노출하지 않고 `app_net` 안에서 service name(`web-a`, `web-b`)으로만 호출된다(2~3교시와 동일 원리). |
| proxy는 어떻게 routing하나? | `nginx/default.conf`의 `location /a/ { proxy_pass http://web-a/; }`, `location /b/ { proxy_pass http://web-b/; }`. upstream 주소가 IP가 아니라 **service name**이다. |
| upstream(web-b)이 죽으면 어디까지 영향인가? | `/b/`만 **504**가 되고 `/a/`는 **200**으로 정상. proxy 자체는 살아있다. **장애가 path(upstream) 단위로 격리**된다 — 3교시 service boundary 격리와 같은 결. |
| 이번엔 왜 502가 아니라 504였나? | upstream이 죽는 방식이 달라서다. 3교시는 `connect() failed (Host is unreachable)` → 즉시 **502**. 이번엔 `upstream timed out` → **504**. 둘 다 "upstream 죽음"이지만 연결 거부/도달 불가는 502, 응답 없이 timeout이면 504다. |
| 사용자 입장에서 gateway 장애와 backend 장애를 어떻게 구분하나? | proxy가 200을 주는 path가 하나라도 있으면(`/a/`) proxy는 살아있는 것. 특정 path만 5xx면 그 **upstream 문제**다. 전부 안 되면 proxy(진입점) 자체 문제일 수 있다. |

## notes

### 가장 단순한 reverse proxy — 진입점 하나, upstream 여럿

3~4교시가 "gateway+API+DB", "web+config+cache"였다면, 5교시는 군더더기를 다 빼고 **reverse proxy의 본질**만 남겼다: 외부는 `proxy` 하나로 들어오고, 내부 upstream은 path로 갈린다.

```text
browser → proxy(18089) ─┬─ /a/ → web-a:80
                        └─ /b/ → web-b:80
                        (그 외 path → 404)
```

| Service | 역할 | 공개 범위 | network |
|---|---|---|---|
| `proxy` | 외부 진입점, `/a/`·`/b/` routing (nginx) | host `18089` | `public_net`, `app_net` |
| `web-a` | 내부 web app A (nginx 정적) | 내부 `80`만 | `app_net` |
| `web-b` | 내부 web app B (nginx 정적) | 내부 `80`만 | `app_net` |

세 컨테이너 모두 같은 `nginx:1.27-alpine` 이미지인데, **proxy는 routing 설정(`default.conf`)을, web-a/b는 정적 파일(`index.html`)을** 마운트해서 역할이 갈린다. 같은 이미지도 **무엇을 마운트하고 어느 network에 두느냐**로 역할이 정해진다.

### routing은 `proxy_pass` + service name

```nginx
location /a/ { proxy_pass http://web-a/; }
location /b/ { proxy_pass http://web-b/; }
```

upstream이 `http://web-a` — IP가 아니라 service name이다(Compose DNS). 3교시 gateway가 `identity-api:3000`으로 보내던 것과 같다.

> 끝의 `/`: `proxy_pass http://web-a/`는 `/a/`를 떼고 나머지를 web-a의 `/`부터 붙인다. 그래서 `/a/`가 web-a의 루트(`index.html`)로 간다.

### 정의 안 된 path는 404 — 3교시와의 차이

3교시는 `location /`에 정적 페이지가 있어 `/`가 200이었다. 5교시 proxy는 `/a/`, `/b/`만 정의하고 **`location /`도 root도 없다.** 그래서 `/`로 들어오면 nginx가 보여줄 게 없어 **404**다(log에 `index.html is not found`).

```text
/a/  → web-a  (200)
/b/  → web-b  (200)
/    → 매칭되는 location 없음 → 404
```

운영 reverse proxy에선 보통 정의 안 된 path를 어디로 보낼지(기본 backend, 404 페이지, redirect) 명시적으로 정한다. "정의 안 한 path는 그냥 404"라는 것도 설계 결정이다.

### 운영 전 처리 — 기본 에러 페이지/버전 노출 가리기

이 lab의 404는 nginx **기본** 에러 페이지다. 실습엔 괜찮지만 운영에선 그대로 두면 안 된다.

| 문제 | 내용 |
|---|---|
| 보안(정보 노출) | 응답에 `nginx/1.27.5`처럼 **버전이 노출**된다. 공격자가 그 버전의 알려진 취약점(CVE)을 골라 노린다 |
| UX/브랜딩 | 흰 배경 `404 Not Found / nginx` 기본 페이지는 불친절. 서비스 디자인의 안내 페이지로 보내야 한다 |

5교시에서 `curl`로 본 `Server: nginx/1.27.5`와 `/` 접근 404가 바로 이 노출이다.

**① 버전 숨기기 — `server_tokens off` (실증).**

```nginx
server {
    server_tokens off;   # 버전 숫자 숨김
    ...
}
```

```text
적용 전:  Server: nginx/1.27.5   본문 하단 "nginx/1.27.5"
적용 후:  Server: nginx          본문 하단 "nginx"
```

> "nginx"라는 이름까지 완전히 지우려면 `more_clear_headers`(headers-more 모듈)가 필요하다. `server_tokens off`는 **버전 숫자**를 가린다.

**② 커스텀 에러 페이지 — `error_page`.**

```nginx
error_page 404            /404.html;
error_page 500 502 503 504 /50x.html;
location = /404.html { root /usr/share/nginx/errors; internal; }
location = /50x.html { root /usr/share/nginx/errors; internal; }
```

`internal`은 "에러 처리용이라 사용자가 URL로 직접 못 연다"는 뜻.

**③ 프론트로 보내기 — redirect / SPA fallback.** "프론트에서 다른 페이지로 보내게"는 보통:

```nginx
error_page 404 https://myapp.com/not-found;   # (a) 안내 페이지로 redirect
error_page 404 =200 /index.html;              # (b) SPA fallback: index.html을 200으로 → 프론트 라우터가 처리
```

(b)는 React/Vue 같은 SPA에서 흔하다. 서버가 404 대신 `index.html`을 주면 client-side router가 "없는 경로" 화면을 직접 그린다. (5교시처럼 `/`가 404 나는 대신 앱이 알아서 처리.)

정리: **①은 거의 필수(보안), ②③은 UX.** 기본 에러 페이지의 버전 노출 가리기는 3교시 Adminer "정보 노출 줄이기"와 같은 결의 보안 습관이다.

### Failure drill — upstream 장애는 path 단위로 격리된다 (실증)

`web-b`만 멈추고 확인:

| 요청 | web-b 중지 후 | 의미 |
|---|---|---|
| `/b/` | **504** | 죽은 upstream 연결 대기 timeout |
| `/a/` | **200** | 다른 upstream이라 영향 없음 |
| proxy 자체 | 살아있음 | 진입점은 정상 |

proxy log: `upstream timed out (110: Operation timed out) while connecting to upstream ... "GET /b/"`. **장애가 path(upstream) 경계로 갇힌다** — `/b/`가 죽어도 `/a/`는 받는다. 3교시 business boundary 격리와 같은 원리가, 여기선 reverse proxy upstream 단위로 나타난다.

### 502 vs 504 — upstream이 "어떻게" 죽었나

3교시(identity-api stop)는 **502**, 5교시(web-b stop)는 **504**가 났다. 둘 다 "upstream 죽음"인데 코드가 다르다. **upstream이 죽는 방식**이 다르기 때문이다.

| 코드 | proxy가 본 것 | 언제 |
|---|---|---|
| 502 Bad Gateway | `connect() failed (Host is unreachable)` | 연결이 **거부/도달 불가** — 즉시 실패 |
| 504 Gateway Timeout | `upstream timed out` | 연결 시도에 **응답이 없어 timeout** — 기다리다 실패 |

같은 "컨테이너 stop"인데 한 번은 502, 한 번은 504가 난 건 네트워크 상태(상대가 즉시 거부했는지, 패킷이 그냥 묻혔는지)에 따라 갈린 것이다. 운영 관점에서 둘 다 **"그 route의 upstream부터 보라"** 는 신호다. 차이는: 504는 timeout이라 **사용자가 그만큼 기다린 뒤** 에러를 받아 체감이 더 나쁘다(그래서 proxy의 connect/read timeout 설정이 중요).

### gateway graph만 보지 마라 — upstream별로 나눠 본다

proxy CPU가 낮아도 특정 upstream이 죽으면 사용자에겐 장애다. proxy 한 장의 그래프(전체 요청 수, CPU)만 보면 "proxy는 멀쩡한데 왜 컴플레인이 오지?"가 된다. **upstream별 status code와 latency를 나눠** 봐야 `/b/`만 504라는 걸 잡는다.

### 트래픽/부하 성향 노트

| Service | 트래픽 성향 | CPU 부하 | 메모리/상태 부하 | 먼저 볼 것 |
|---|---|---|---|---|
| `proxy` | 전체 외부 요청 진입 | TLS/압축/access log 많으면 증가 | connection buffer | access/error log, upstream status |
| `web-a` | `/a/` traffic | 정적이면 낮음, API면 app logic | app cache/session | `/a/` 응답 시간 |
| `web-b` | `/b/` traffic | path별 기능 차이 | app cache/session | `/b/` 응답 시간 |

(이 proxy도 3교시처럼 "하나면 SPOF"다 — 운영에선 proxy를 여러 대 + LB 뒤에 두거나 AWS ALB 같은 관리형으로 떠넘긴다.)

### 운영에선 이 nginx proxy를 ALB/Ingress가 대체한다

**proxy를 여러 대로 늘리면 앞에 LB(ALB)가 필요하다.** proxy 하나는 SPOF라, HA/scale 하려면 "어느 proxy로 보낼지" 나눠줄 LB가 앞에 있어야 한다. 이때 proxy 자신이 LB의 upstream(target)이 된다.

```text
사용자 → ALB ─┬─ nginx proxy #1 ─┐
              ├─ nginx proxy #2 ─┼─→ 내부 upstream(web-a/web-b)
              └─ nginx proxy #3 ─┘
```

그런데 한 발 더 나가면 질문이 생긴다: **ALB도 L7이라 path 라우팅(`/a/`→A, `/b/`→B)을 직접 한다.** 그럼 nginx가 하던 일을 ALB가 하잖아? → **단순 라우팅이면 nginx proxy 층을 아예 빼는 경우가 많다.**

```text
[직접 nginx]  사용자 → nginx(라우팅) → 앱들
[요새 흔함]   사용자 → ALB(listener rule로 라우팅) → 앱들       # nginx 별도 층 없음
[쿠버네티스]  사용자 → ALB/Ingress Controller → 앱들           # nginx는 ingress 안으로
```

**단, nginx가 사라진 게 아니라 위치가 옮겨간 것이다.**

| nginx가 남는 곳 | 설명 |
|---|---|
| k8s Ingress Controller | 쿠버네티스 reverse proxy 역할 = 보통 **nginx-ingress**(또는 Traefik/Envoy). nginx가 ingress 안으로 |
| 컨테이너 안 web server | 정적/SPA 서빙은 여전히 nginx (이 lab의 web-a/b처럼) |
| ALB가 못 하는 것 | 복잡한 rewrite, 캐싱, 세밀한 헤더 조작, 특수 라우팅 |
| on-prem / 비 AWS | 관리형 LB가 없으면 nginx/HAProxy 직접 |

언제 무엇을 쓰나:

| 상황 | 선택 |
|---|---|
| 단순 path/host 라우팅 + TLS + 관리형 HA | **ALB만** (nginx 층 생략) |
| 복잡한 rewrite/캐싱/커스텀 설정 | **ALB + nginx**(또는 nginx-ingress) |
| 쿠버네티스 | **Ingress Controller**(내부적으로 nginx인 경우 많음) |
| 정적/SPA 서빙 | nginx는 그대로(서버 역할) |

핵심: **"라우팅"을 누가 하느냐**의 문제다. 옛날엔 직접 띄운 nginx가, 요새는 ALB/Ingress가 한다 — 관리형이라 SPOF·스케일을 알아서 처리하니까(4교시 TLS offload, 3교시 gateway HA와 같은 맥락). 그래도 ALB가 못 하는 세밀한 건 여전히 nginx 몫이다. 이 lab은 그 "라우팅"의 본질을 가장 단순한 형태로 보여준 것.

> **용어**: Ingress = k8s에서 "외부 → 내부 서비스" 라우팅 **규칙(YAML)**, Ingress Controller = 그 규칙을 실행하는 **실제 프록시(보통 nginx)**. 메뉴판(규칙) vs 주방(실행). 5교시 `default.conf`의 `location /a/ { proxy_pass ... }`를 k8s에선 Ingress YAML(`path: /a/ → service: web-a`)로 적고, controller가 내부적으로 nginx 설정으로 바꿔 실행한다 — 하는 일은 같고 적는 방식이 표준화·자동화된 것. (더 최신은 Gateway API.)

### Week 3 다리 — compose 컨테이너 vs k8s Pod

쿠버네티스의 최소 실행 단위는 **컨테이너가 아니라 Pod**다. compose의 `web-a`(컨테이너 1개)가 k8s에선 `web-a` **Pod**가 되고, Pod 안엔 컨테이너가 **여러 개** 들어갈 수 있다.

| | docker compose (5교시) | 쿠버네티스 |
|---|---|---|
| 최소 단위 | 컨테이너 (`web-a` = 컨테이너) | **Pod** (컨테이너 1개 이상 묶음) |
| web-a | nginx 컨테이너 하나 | nginx + 보조 컨테이너가 든 Pod |

같은 Pod 안 컨테이너들은 **network(localhost)·volume을 공유**하고 **항상 같이 뜨고 같이 죽는다**. "한 몸처럼 붙어 돕는 보조"를 함께 두는 게 **sidecar 패턴**이다(로그 수집기, Envoy proxy, config 동기화, init container 등).

주의 — 헷갈리기 쉬운 구분:

```text
같은 Pod 안 여러 컨테이너 = 메인 + 보조(sidecar), 한 몸 → 같이 뜨고 같이 scale
서로 다른 Pod/서비스      = 독립 기능(web-a vs web-b) → 따로 scale (3교시 자원 프로파일 쪼개기)
```

3교시 "자원 프로파일로 service 쪼개기"는 **별도 Pod**로 나누는 것이고, **같은 Pod 안 여러 컨테이너**는 쪼개는 게 아니라 메인+보조를 묶는 것 — 정반대 목적이다. 단, **실무 대부분의 Pod은 컨테이너 1개**다. sidecar가 필요할 때만 여러 개 둔다("가능"이지 "항상"이 아님).

### Cleanup 기준

```bash
docker compose down       # container + network 정리 (volume 없음 → -v 불필요)
```

### 흔한 오해 / 실패

- upstream도 host port가 있어야 한다 → proxy가 service name으로 호출하므로 불필요. 안 여는 게 설계 의도.
- 정의 안 된 path도 알아서 처리된다 → `location` 없으면 404. 기본 동작도 명시적으로 정해야 한다.
- upstream 장애 = 항상 502 → 죽는 방식에 따라 502(거부/불가) 또는 504(timeout). 둘 다 upstream부터 본다.
- proxy 그래프가 정상이면 서비스 정상 → upstream별로 나눠 봐야 `/b/`만 죽은 걸 잡는다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| `/b/`가 504, `/a/`는 200 | upstream(web-b)이 죽거나 응답 없음. proxy logs에서 `upstream timed out ... "GET /b/"` 확인 → web-b container 상태(`docker compose ps`)부터 점검. `/a/`가 200이면 proxy는 정상 |
| `/`가 404 | 고장 아님. nginx에 `location /`/root가 없어서. 정의된 `/a/`, `/b/`만 routing됨 |
