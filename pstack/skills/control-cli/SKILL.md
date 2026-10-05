---
name: control-cli
description: "Drive a CLI or TUI the way a user does, to reproduce a bug or prove a change, and capture the real output as evidence. Use for /control-cli, CLI or TUI repro, or the poteto-mode 'shipping CLI' and bug-fix repro steps."
disable-model-invocation: true
---

# Control CLI

Reproduce and prove CLI and TUI behavior by running the real binary yourself. Captured output from the built artifact beats any claim about what the code prints.

## Pick the harness

1. **A project verify skill.** If `.claude/skills/verify-*/` exists for this tool, use it. Its launch, doctor, and feature map win. If none exists and the tool will be driven more than once, offer the **create-verification-skill** skill.
2. **Plain CLI.** Build the real binary the way users get it (the repo's build or install command), then run it with Bash.
3. **TUI or interactive prompt.** Script it with tmux, one isolated session per drive.

```bash
s=pstack-$$
tmux new-session -d -s "$s" -x 120 -y 40 '<command>'
tmux send-keys -t "$s" '<keys>' Enter
tmux capture-pane -t "$s" -p > "$EVIDENCE/step-1.txt"
tmux kill-session -t "$s"
```

Wait for a prompt string or screen text before each keystroke (poll `capture-pane` for it), not a fixed sleep.

## Drive

- Run it the way a user would, from a clean working directory with realistic arguments, env, and config.
- Record stdout, stderr, and the exit code for every command (`cmd >out.txt 2>err.txt; echo $? >code.txt`).
- Reproduce before fixing. Then rerun the same commands after the fix and diff the captures.
- Check side effects directly (files written, git refs, network calls), not the tool's own success message. A `--dry-run` proves only what you observed it skip.

## Evidence

Save to a directory you name in the reply (default `${TMPDIR:-/tmp}/pstack-evidence/<slug>/`). Keep the before and after captures side by side.

Kill only the sessions and processes you started. Evidence survives cleanup.

**Reply:** the binary and build used, the commands or keystrokes driven, before and after output, and the evidence paths.
