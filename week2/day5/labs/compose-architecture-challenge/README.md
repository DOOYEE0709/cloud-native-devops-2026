# Compose Architecture Challenge Lab

이 폴더는 W2D5 `session-09-challenge.md`에서 사용하는 자율 설계 workspace다. 강사가 architecture keyword set을 지정하거나 학생이 하나를 선택하면, 이 폴더 안에서 직접 `compose.yaml`과 필요한 최소 앱 파일을 만든다.

## 시작
```bash
cd /mnt/d/paperclip/week2/day5
sed -n '1,260p' session-09-challenge.md
cd labs/compose-architecture-challenge
```

## 권장 파일
| 파일/폴더 | 설명 |
|---|---|
| `compose.yaml` | 직접 작성 |
| `README.md` | 실행 방법과 구조 설명 |
| `NOTES.md` | 증거와 판단 표 |
| `apps/` | Node.js API나 worker 코드가 필요할 때 생성 |
| `html/` | frontend/static page가 필요할 때 생성 |
| `db/` | PostgreSQL init SQL이 필요할 때 생성 |

## 금지된 shortcut
- Day 5 기존 template의 `compose.yaml`을 그대로 복사해 service 이름만 바꾸기
- 모든 service를 default network 하나에 넣기
- DB를 host port로 공개하기
- 기록 문서에 secret/password 값을 그대로 적기
- `docker compose config`만 보고 실제 실행 증거를 생략하기

## 완료 기준
다른 학생이 이 폴더만 보고 다음을 실행할 수 있어야 한다.

```bash
docker compose config
docker compose up -d
docker compose ps
```

그리고 `NOTES.md`에서 외부 진입점, 내부 service name, network area, volume, traffic/CPU/memory pressure, 실패 주입 결과를 확인할 수 있어야 한다.
