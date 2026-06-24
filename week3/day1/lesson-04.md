# 4교시: 표준 MSA 실습 앱 토폴로지

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `docker compose config` | topology 그림에 연결 지점 매핑 |
| `18083:80` | browser → frontend |
| `proxy_pass http://api:8080/api/` | frontend → api |
| `DB_HOST=db` | api → db |
| `API_URL=http://api:8080/api/status` | worker → api |
| `msa-db-data` | db → volume |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 사용자 요청 경로(user path)는? | browser → frontend(nginx) → api → db. frontend가 정적 페이지를 주고 `/api/`는 api로 reverse proxy 한다. |
| worker 경로는? | worker → api → db. 외부 port 없이 주기적으로 api를 호출하고 결과를 로그로 남기는 background 경로다. |
| frontend는 DB에 직접 붙는가? | 아니다. frontend는 api만 호출하고, DB 접근은 api가 담당한다. |
| API가 Up이면 DB도 정상인가? | 아니다. `api process 살아있음 ≠ service ready`. DB 연결 실패 시 running이어도 `/health`에서 503이 날 수 있어 JSON을 확인해야 한다. |

## notes

### 전체 구조

```text
browser
  -> frontend nginx
    -> api
      -> db

worker
  -> api
    -> db
```

| Service | 역할 | 사용자 요청 경로 포함 |
|---|---|---|
| `frontend` | 정적 페이지 제공, `/api/` reverse proxy | 포함 |
| `api` | 상태 API 제공, DB 연결 확인 | 포함 |
| `worker` | 주기적으로 API 상태 확인 | 미포함 |
| `db` | PostgreSQL backing service | 직접 미포함 |

### frontend nginx 설정 읽기

```nginx
server {
    listen 80;
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
    location /api/ {
        proxy_pass http://api:8080/api/;
        proxy_set_header x-request-id $http_x_request_id;
        proxy_connect_timeout 2s;
        proxy_read_timeout 5s;
    }
}
```

| 설정 | 의미 |
|---|---|
| `listen 80` | frontend container 내부 port는 80 |
| `location /` | 정적 HTML 제공 |
| `location /api/` | browser의 `/api/` 요청을 api service로 넘김 |
| `proxy_pass http://api:8080/api/` | nginx container가 Compose DNS `api`를 사용 |
| `proxy_set_header x-request-id` | request id를 API log로 전파 |
| `proxy_connect_timeout 2s` | API 연결 지연이 무한 대기로 가지 않게 함 |

### nginx 기본 사이트 override와 정적 페이지 독립성

공식 `nginx` 이미지는 기본 설정(`default.conf`)과 기본 페이지("Welcome to nginx!" `index.html`)를 갖는데, compose가 둘 다 bind mount로 덮어쓴다 → **기본 Welcome 사이트는 우리 페이지로 교체**된다.

```nginx
location / {
    root /usr/share/nginx/html;   # 파일을 찾을 폴더
    index index.html;             # / 요청이 오면 index.html 응답
}
```

| 해석 | 맞나? |
|---|---|
| 우리 설정 /index를 넣으면 nginx 기본 Welcome 화면은 안 뜬다 | ⭕ (default.conf·index.html을 override했으니) |
| index.html이 없거나 에러 시 기본 Welcome으로 fallback 한다 | ❌ fallback 안 함 → **403/404 에러 코드 반환** |

즉 한 번 override하면 에러가 나도 nginx 기본 사이트로 되돌아가지 않는다. 정확한 이유는 "index를 설정해서"보다 **기본 설정/페이지를 override해서**.

**정적 페이지는 backend 에러와 독립:**

```text
location /      → nginx가 직접 정적 index.html 제공 (api 불필요)
location /api/  → api로 proxy (여기가 backend 의존)
```

`/` 정적 페이지는 nginx 혼자 서빙하므로 api/db가 죽어도 **화면 자체는 뜬다**(데이터만 비어 있음). 에러는 `/api/` proxy 쪽에서 난다 → "frontend만 정상: 화면은 뜨지만 데이터 없음" 상황.

### API의 dependency

```python
DB_HOST = os.environ.get("DB_HOST", "db")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
```

api는 요청 시 DB socket 연결을 시도하고, `/health`·`/api/status`에서 DB 연결 가능 여부를 JSON으로 반환한다.

```text
api process가 살아 있음 != api가 service ready 상태임
```

DB 연결이 실패하면 api는 running이어도 `/health`에서 503을 줄 수 있다.

### worker 경로

```python
API_URL = os.environ.get("API_URL", "http://api:8080/api/status")
```

worker는 외부 port가 없다. 주기적으로 api를 호출해 결과를 로그로 남긴다. 사용자가 직접 호출하지 않지만, worker 로그는 **내부 dependency 상태를 보여주는 좋은 증거**다.

### docker network 격리 = 보안 한 겹 (겹벽)

내부 network에서 api가 db에 접근할 때, db는 host에 port를 안 열고 **내부 network(`msa-net`) 안에서만** 접근된다. 이 network 경계가 보안을 한 겹 더 만든다.

```text
[ host (내 맥) ]
  localhost:18083 → frontend  (열림, 사용자 진입)
  localhost:18084 → api       (열림, debug용)
  db                          ← host에 안 열림
──────────────────────────────────  ← 겹벽 (network 경계)
[ msa-net (docker 내부 network) ]
  frontend:80 → api:8080 → db:5432  (내부에서만 통신)
```

| 구분 | `ports:` | host에서 접근 | 누가 접근 가능 |
|---|---|---|---|
| frontend, api | 있음(18083, 18084) | 가능 | host의 누구나 |
| db | **없음** | 불가 | **같은 network의 service만** (= api) |

db에 `ports:`가 없으면 host/외부에서 직접 `db:5432`로 못 붙고, 같은 `msa-net`의 api만 service name `db`로 접근한다. 공격자가 host에 들어와도 db는 경계 안에 숨어 있어 한 단계 더 뚫어야 한다 → **네트워크 분리(segmentation) / 다층 방어(defense in depth)**.

| 계층 | 실무 예시 |
|---|---|
| 외부 노출(public) | frontend, gateway, load balancer |
| 내부 service network | api, 비즈니스 service들 |
| 더 안쪽(private/data) | DB, 캐시 — 별도 network·서브넷에 격리 |

실무에서는 같은 network 안에서도 방화벽 규칙, k8s NetworkPolicy, DB credential, TLS를 더 겹친다. 계층마다 통과 조건이 추가되는 구조.

### 잘못 이해하기 쉬운 지점

| 오해 | 정정 |
|---|---|
| frontend가 DB에 직접 붙는다 | frontend는 API만 호출한다 |
| worker가 사용자 요청을 처리한다 | worker는 background 확인 루프다 |
| host에서 DB에 접속해야 한다 | 이 실습에서 DB는 host port를 공개하지 않는다 |
| API가 Up이면 DB도 정상이다 | `/health` JSON을 봐야 한다 |

### 핵심

토폴로지는 그림을 예쁘게 그리는 일이 아니다. 요청이 어디로 흐르고, 어느 지점이 실패하면 어떤 service log를 봐야 하는지 결정하는 **운영 지도**다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
