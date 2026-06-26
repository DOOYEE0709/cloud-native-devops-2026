# 5교시: PR, Merge, Rebase, Revert, Tag 운영

## 실습 확인 기록

> sandbox: `/tmp/w3d3-git-sandbox` (setup.sh가 mac에서 안 돌아 동일 동작을 수동 재현, Blocker Log 참고)

| 명령/확인 | 결과 |
|---|---|
| `git log --graph --all` | main, feature/change-message, hotfix/main-message 3개 branch. hotfix는 merge --no-ff로 main에 병합됨 |
| `git switch feature; git rebase main` | `app.txt` message 줄 충돌 → `CONFLICT (content)`, `git status -s` = `UU app.txt` |
| `git rebase --abort` | rebase 전 상태로 복구 (status 깨끗) |
| `git revert HEAD --no-edit` | 새 commit `703895f Revert "prepare release metadata"` 생성 — 원본 commit은 그대로 남음 |
| `git tag v0.1.0` / `git tag --list` | tag `v0.1.0` 생성·조회, `git show --stat`으로 가리키는 commit 확인 |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| merge / squash / rebase 차이? | merge=이력 보존(복잡) / squash=PR을 commit 1개로(세부 사라짐) / rebase=linear(공유 branch 주의) |
| revert는 commit을 지우나? | 아니오. 반대 변경을 **새 commit**으로 추가. 공유 branch에서 안전 |
| conflict 났을 때 즉시 빠져나오려면? | `git rebase --abort` (또는 merge면 `git merge --abort`) |
| tag의 용도? | 릴리스 지점 고정. Docker image tag와 연결 가능 |
| Git revert와 Docker rollback의 차이? | revert=코드 이력 되돌리는 commit / rollback=배포된 이전 image tag로 실행 (별개 기준) |

## notes

### Merge 방식 비교
- merge commit: branch 이력 보존, history 복잡. / squash: PR 하나를 commit 하나로 정리, 세부 commit 사라짐. / rebase: linear history, 공유 branch rebase 주의.

### 메모 — git tag
- tag = 특정 commit에 붙이는 **고정된 이름표**. 주로 릴리스 버전 표시(`v0.1.0`).
- branch는 commit하면 따라 이동(움직임), tag는 그 자리에 멈춤(고정).
- 명령: `git tag v0.1.0`(HEAD에 부착) / `git tag --list`(조회) / `git show v0.1.0`(내용) / `git tag v0.1.0 <hash>`(특정 commit).
- **commit과 tag는 별개 동작.** 한 번에 하는 명령 없음 → commit 먼저, 그 뒤 그 commit에 tag 부착.
- 종류: lightweight(`git tag v0.1.0`) vs annotated(`git tag -a v0.1.0 -m "..."`, 작성자·날짜·메시지 포함, 릴리스 권장).

### Revert vs Rollback 구분
- Git revert = 코드 이력 되돌리는 commit / Docker image rollback = 이전 image tag로 실행 / K8s rollout undo = 이전 ReplicaSet / DB rollback = migration·data 복구.

### 핵심 포인트
- 공유 branch에서 history를 지우는 방식(force push/rebase)은 위험. 이미 올라간 변경은 **revert로 남기고**, 배포된 artifact는 별도 **rollback 기준**으로 다룬다.

### Evidence Note
```markdown
# W3D3S5 PR Merge Operations
- merge method: merge --no-ff (hotfix), 운영 PR은 squash 권장
- conflict file: app.txt (message 줄)
- revert commit: 703895f Revert "prepare release metadata"
- tag: v0.1.0
- rollback target: 이전 image tag (예: 0.1.0) — revert와 별개
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
