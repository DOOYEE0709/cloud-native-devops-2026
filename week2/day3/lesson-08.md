# 8교시: Delivery handoff와 구름 EXP 배움일기

## 실습 확인 기록

### 최종 상태 확인

| 명령 | 설명 | 결과 |
|---|---|---|
| `docker images paperclip-static-site` | 전체 tag 목록 확인 | ![images](assets\lesson-08\images.png) |
| `docker ps -a --filter name=paperclip-day3-static` | container 상태 확인 | ![ps](assets\lesson-08\ps.png) |
| `docker history paperclip-static-site:day3` | layer 흔적 확인 | ![history](assets\lesson-08\history.png) |
| `docker image inspect paperclip-static-site:day3 --format "{{.Id}} {{.Size}} {{json .RepoTags}}"` | image 메타데이터 확인 | ![inspect](assets\lesson-08\inspect.png) |
| `docker scout cves --only-severity critical,high paperclip-static-site:day3 \|\| true` | 취약점 점검 | ![scout](assets\lesson-08\scout.png) |

### Cleanup

| 명령 | 설명 | 결과 |
|---|---|---|
| `docker stop paperclip-day3-static paperclip-day3-static-wrong paperclip-day3-bad-cmd \|\| true` | 실습 container 중지 | ![cleanup-stop](assets\lesson-08\cleanup-stop.png) |
| `docker rm paperclip-day3-static paperclip-day3-static-wrong paperclip-day3-bad-cmd \|\| true` | 실습 container 삭제 | ![cleanup-rm](assets\lesson-08\cleanup-rm.png) |
| `rm -rf week2/day3/labs/static-site-broken` | 실습 복사본 삭제 | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Day 3 완료 기준은 무엇인가? | "image 하나 만들었다"가 아니라 "다른 사람이 build/run/verify/scan/failure recovery를 재현할 수 있다"다. |
| 운영 인수인계에서 꼭 있어야 할 것은? | 어느 directory에서 build하는지, image tag, port, 정상 확인 방법, scan 결과, 실패 시 어디부터 볼지다. |
| container 삭제와 image 삭제의 차이는? | container 삭제(`docker rm`)는 실행 인스턴스를 지우는 것이고, image 삭제(`docker image rm`)는 실행 재료 자체를 지우는 것이다. |
| cleanup에서 image를 바로 삭제하지 않는 이유는? | Day 4에서 같은 image를 다시 쓰기 때문이다. 필요할 때만 삭제한다. |

## notes

### 인수인계 표

| 구분 | 내용 | 확인 명령 | 합격 기준 |
|---|---|---|---|
| 소스 위치 | 실습 앱 directory | `pwd`, `ls -la` | `week2/day3/labs/static-site`와 필수 파일 확인 |
| image tag | 최종 제출 image tag | `docker images paperclip-static-site` | `day3`, `day3-reviewed`, 버전/환경 tag 의미 설명 가능 |
| build 명령 | image를 만든 명령 | `docker build -t ... .` | build 성공 + image 목록에 표시 |
| 실행 명령 | container 실행 명령 | `docker run -d --name ... -p ...` | container 이름과 port mapping 설명 가능 |
| 정상 확인 | HTTP 응답 기준 | `curl -I`, `curl -s` | `HTTP/1.1 200 OK`와 페이지 문구 확인 |
| 취약점 점검 | Docker Scout 결과 | `docker scout cves ...` | critical/high 없음 또는 blocker 사유 기록 |
| image 증거 | layer와 metadata | `docker history`, `docker image inspect` | `COPY index.html`, `COPY styles.css`, id/size/tag 확인 |
| 실패 분석 | 재현한 실패와 원인 | 실패 출력, `docker logs`, `docker ps` | build/run/verify/hygiene 중 어느 단계 문제인지 분류 |
| 복구 확인 | 수정 후 재확인 결과 | 재실행한 build/run/curl | 같은 문제가 해결됐음을 출력으로 확인 |
| 정리 작업 | container/복사본 정리 | cleanup 명령 | 불필요한 container와 임시 directory 제거 |
| registry 판단 | push 여부 | push gate 체크 | local only 또는 push candidate 사유 설명 |
| secret/context 점검 | 민감 정보 포함 여부 | `.dockerignore`, `find`, `du -sh` | `.env`, token, dependency/cache 제외 확인 |

### 작성 예시

| 구분 | 기록 예시 |
|---|---|
| image tag | `paperclip-static-site:day3-reviewed`, 수업 검수 완료 tag |
| 정상 확인 | `curl -I http://localhost:18083` → `HTTP/1.1 200 OK` |
| 취약점 점검 | Scout 실행, critical/high 없음 |
| 실패 분석 | missing file 실패 — `COPY index.html ... not found`, build context 문제 |
| registry 판단 | secret/context 확인 전이므로 push하지 않고 local only |

### 퇴근 전 최종 확인 원칙

"문제 없다"고 퇴근하지 말고 **한 번 더 직접 확인하고 퇴근한다.**

특히 Terraform처럼 인프라를 건드리는 작업은 강사님도 `plan`을 여러 번 세우고 진행한다고 하셨다. apply 전에 plan 결과를 꼭 읽고, 예상한 변경만 있는지 확인한 뒤 실행한다.

```text
"될 것 같다" ≠ "됐다"

확인 전 퇴근 → 밤에 장애 → 큰일남
```

| 작업 유형 | 퇴근 전 확인 |
|---|---|
| Docker image | `curl`로 HTTP 200 직접 확인 |
| Terraform | `plan` 결과 읽고 예상 변경만 있는지 확인 후 `apply` |
| 배포 | 로그와 health check 응답 직접 눈으로 확인 |
| cleanup | `docker ps -a`로 남은 container 없는지 확인 |

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
