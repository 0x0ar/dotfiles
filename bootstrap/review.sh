#!/usr/bin/env bash
set -euo pipefail
source_dir="$(chezmoi source-path)"
[[ -d "$source_dir/.git" ]] || { echo 'Run chezmoi init first' >&2; exit 1; }
git -C "$source_dir" status --short
printf '\nTracked differences:\n'
git -C "$source_dir" diff --stat
git -C "$source_dir" diff --check
printf '\nUntracked files (inspect manually before committing):\n'
git -C "$source_dir" ls-files --others --exclude-standard
printf '\nSecret scanner: '
if command -v gitleaks >/dev/null; then
  echo 'installed (run scripts/approve.sh for a full scan)'
else
  echo 'not installed (approval requires gitleaks)'
fi
