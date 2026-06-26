# W3D3 Git Sandbox

This sandbox creates an isolated Git repository under `/tmp/w3d3-git-sandbox`.

It is safe for class because it does not modify the lecture repository history.

## Create Sandbox
```bash
bash week3/day3/labs/git-sandbox/setup.sh
cd /tmp/w3d3-git-sandbox
```

macOS에서 아래 오류가 보이면 오래된 `setup.sh`의 `sed -i` 호환성 문제다. 실행 권한 문제가 아니다.

```text
sed: 1: "app.txt
": command a expects \ followed by text
```

최신 스크립트는 macOS BSD sed와 Linux GNU sed 차이를 피하도록 수정되어 있다. 다시 내려받은 뒤 같은 명령을 실행한다.

## Inspect History
```bash
git log --oneline --graph --decorate --all
git branch --show-current
git status
```

## Conflict Drill
```bash
git switch feature/change-message
git rebase main
```

Expected: conflict in `app.txt`.

Abort if needed:

```bash
git rebase --abort
```

## Revert Drill
```bash
git switch main
git log --oneline -3
git revert HEAD --no-edit
git log --oneline -4
```

## Tag Drill
```bash
git tag v0.1.0
git tag --list
git show --stat v0.1.0
```
