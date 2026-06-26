#!/usr/bin/env bash
set -euo pipefail

SANDBOX_DIR="${SANDBOX_DIR:-/tmp/w3d3-git-sandbox}"

rm -rf "${SANDBOX_DIR}"
mkdir -p "${SANDBOX_DIR}"
cd "${SANDBOX_DIR}"

git init -q -b main
git config user.name "W3D3 Student"
git config user.email "student@example.com"

cat > app.txt <<'EOF'
version=0.1.0
message=hello from main
feature=off
EOF

git add app.txt
git commit -q -m "initial app"

replace_in_file() {
  local old_text="$1"
  local new_text="$2"
  local file="$3"
  local tmp_file

  tmp_file="$(mktemp)"
  sed "s/${old_text}/${new_text}/" "${file}" > "${tmp_file}"
  mv "${tmp_file}" "${file}"
}

git switch -q -c feature/change-message
replace_in_file 'message=hello from main' 'message=hello from feature' app.txt
git add app.txt
git commit -q -m "change message on feature"

git switch -q main
git switch -q -c hotfix/main-message
replace_in_file 'message=hello from main' 'message=hello from hotfix' app.txt
git add app.txt
git commit -q -m "hotfix message on main line"

git switch -q main
git merge --no-ff hotfix/main-message -m "merge hotfix"

printf 'release=dev\n' >> app.txt
git add app.txt
git commit -q -m "prepare release metadata"

cat <<EOF
Sandbox created: ${SANDBOX_DIR}

Branches:
$(git branch --all)

Try:
  cd ${SANDBOX_DIR}
  git log --oneline --graph --decorate --all
  git switch feature/change-message
  git rebase main

The rebase should create a conflict in app.txt.
EOF
