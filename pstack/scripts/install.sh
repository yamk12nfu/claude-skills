#!/usr/bin/env bash
# Install pstack for Claude Code as a skills-dir plugin.
#
#   bash scripts/install.sh            link ~/.claude/skills/pstack -> this checkout
#   bash scripts/install.sh --dry-run  show what would happen
#
# Every pstack file refers to ~/.claude/skills/pstack, so the link path is fixed.
# The model rule (~/.claude/rules/pstack-models.md) is written by /setup-pstack,
# not here. Without it, pstack runs on the bundled defaults.
set -euo pipefail

dry=false
[ "${1-}" = "--dry-run" ] && dry=true
run() { if $dry; then echo "[dry-run] $*"; else "$@"; fi; }

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$HOME/.claude/skills/pstack"

if [ -L "$dest" ]; then
	current="$(readlink "$dest")"
	if [ "$current" = "$src" ]; then
		echo "already linked: $dest -> $src"
	else
		echo "relinking: $dest -> $src (was $current)"
		run ln -sfn "$src" "$dest"
	fi
elif [ -e "$dest" ]; then
	echo "error: $dest exists and is not a symlink. Move it away first." >&2
	exit 1
else
	run mkdir -p "$(dirname "$dest")"
	run ln -s "$src" "$dest"
	echo "linked: $dest -> $src"
fi

bin_dest="$HOME/.local/bin/claude-pstack"
if [ "$(readlink "$bin_dest" 2>/dev/null)" = "$src/bin/claude-pstack" ]; then
	echo "already linked: $bin_dest"
else
	run mkdir -p "$(dirname "$bin_dest")"
	run ln -sfn "$src/bin/claude-pstack" "$bin_dest"
	echo "linked: $bin_dest (starts Claude Code with the task list on)"
fi

command -v codex >/dev/null && echo "codex: $(codex --version)" || echo "warn: codex CLI not found. codex:* seats will fall back to claude:opus."
[ -f "$HOME/.claude/rules/pstack-models.md" ] && echo "model rule: ~/.claude/rules/pstack-models.md" || echo "next: run /setup-pstack in Claude Code to choose models (defaults apply until then)."
echo "next: start a session with claude-pstack and run /poteto-mode <task>."
