# Dotfiles project rules
- Treat Omarchy system-managed files as read-only.
- Manage only user configuration under HOME; do not collect credentials, browser profiles, tokens or private keys.
- Never invoke git commit, push, apply, or filesystem deletion without explicit human approval.
- Inspect symlinks before using `chezmoi add`.
- Do not assume every file in ~/.config is suitable for version control.
- Prefer reproducible, minimal overrides over generated output.
