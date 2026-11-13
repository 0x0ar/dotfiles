#!/usr/bin/env bash
set -euo pipefail
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/dotfiles-capture-${UID}.lock"
flock -n 9 || exit 0
command -v chezmoi >/dev/null || { echo 'Missing chezmoi' >&2; exit 1; }
source_dir="$(chezmoi source-path)"
[[ -d "$source_dir/.git" ]] || { echo "Git repo missing at $source_dir" >&2; exit 1; }
# Captures only previously managed, modified regular files; templates are ignored.
chezmoi re-add
# Packages: snapshot the names of explicitly installed packages only.
# Opt-in: create packages/.enable-snapshot to activate snapshots.
if [[ -f "$source_dir/packages/.enable-snapshot" ]] && command -v pacman >/dev/null; then
  mkdir -p "$source_dir/packages"
  pacman -Qqen | sort > "$source_dir/packages/pacman.txt"
  pacman -Qqem | sort > "$source_dir/packages/aur.txt"
fi
printf 'Dotfiles captured. Review with: %s\n' "git -C '$source_dir' status --short"
