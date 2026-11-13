#!/usr/bin/env bash
set -euo pipefail
source_dir="$(chezmoi source-path)"
[[ -d "$source_dir/.git" ]] || { echo 'No git repo found' >&2; exit 1; }
command -v gitleaks >/dev/null || { echo 'Install gitleaks before publishing' >&2; exit 1; }
cd "$source_dir"
[[ -z "$(git ls-files --others --exclude-standard)" ]] || { echo 'Untracked files found: review and git add them explicitly first.' >&2; git ls-files --others --exclude-standard; exit 1; }
git diff --check
echo 'Current changes:'
git status --short
echo
read -r -p 'Stage ALL tracked changes for review? [y/N] ' answer
[[ "$answer" == y || "$answer" == Y ]] || exit 0
git add -u
if git diff --cached --quiet; then echo 'Nothing to commit'; exit 0; fi
printf '\nStaged summary:\n'
git diff --cached --stat
printf '\nStaged files:\n'
git diff --cached --name-only
# Scan staged content, including tracked file modifications, using a temporary git patch.
# gitleaks git scan examines commits rather than uncommitted staged changes;
# scan working directory and fail closed for any detection.
gitleaks dir --no-banner --redact --exit-code 1 .
git diff --cached --check
read -r -p 'Commit these staged changes? [y/N] ' answer
[[ "$answer" == y || "$answer" == Y ]] || exit 0
read -r -p 'Commit message: ' message
[[ -n "${message// /}" ]] || { echo 'Commit message is required' >&2; exit 1; }
git commit -m "$message"
read -r -p 'Push to configured origin? [y/N] ' answer
if [[ "$answer" == y || "$answer" == Y ]]; then
  git remote get-url origin >/dev/null
  git push
fi
