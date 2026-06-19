# Weekend 3-Tier Challenge Lab Files

이 폴더는 W2D3 `session-09-challenge.md`에서 사용하는 실습 파일 모음이다. 과제 설명, 실행 순서, 제출 기준은 상위 세션 문서를 기준으로 진행한다.

```bash
cd /mnt/d/paperclip/week2/day3
sed -n '1,260p' session-09-challenge.md
```

## File Map
| Path | 역할 |
|---|---|
| `frontend/Dockerfile` | nginx frontend image |
| `frontend/html/index.html` | 정적 frontend HTML |
| `frontend/html/styles.css` | 정적 frontend CSS |
| `frontend/nginx.conf` | `/api/` 요청을 backend로 proxy |
| `backend/Dockerfile` | Node.js hello world backend image |
| `backend/server.js` | `/health`, `/api/info` 응답 |
| `scripts/measure-build.sh` | 최초 build 시간과 image size 측정 |
| `SUBMISSION.md` | 제출 표 템플릿 |

## Success Shape
```text
frontend: index.html + styles.css
backend: Node.js hello world
database: postgres:16 + paperclip-weekend-pgdata named volume
network: frontend -> backend, backend -> database only
```
