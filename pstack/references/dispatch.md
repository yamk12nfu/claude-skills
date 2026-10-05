# Dispatch: running a pstack seat on Claude or Codex

Every pstack skill that spawns a subagent names a **role** (a line in the pstack-models rule) and a **mode** (`read` or `write`). This file is the one protocol for turning that into a running seat. Skills do not repeat it. `$PSTACK` is `~/.claude/skills/pstack`.

## 1. Resolve the role

```bash
~/.claude/skills/pstack/scripts/pstack-model "<role>"
```

It prints one value per line. A panel role (arena runners, architect runners, interrogate reviewers, arena cross-judge pool) prints one line per seat, and the line count is the fan-out. A single-seat role prints one line. The script falls back to the bundled default when the user rule or the line is missing, so never hard-code a model in a skill.

| Value | Runs as |
|---|---|
| `claude:<model>` | Claude Code subagent via the Agent tool, `model: <model>` (`fable`, `opus`, `sonnet`, `haiku`). |
| `inherit-parent` | Claude Code subagent via the Agent tool with `model` omitted (the parent's model). Never treat it as a rejected value. |
| `codex:<model>:<effort>` | Codex CLI via `$PSTACK/scripts/codex-run`, launched with Bash `run_in_background: true`. |

Model families are `claude` and `codex`. "A different family from the parent" means a `codex:*` seat, since the parent is Claude.

## 2. Write the brief to a file

Make one run directory per skill invocation and one seat directory per seat.

```bash
RUN="${TMPDIR:-/tmp}/pstack-runs/<skill>-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN/<seat-label>"
```

Write the seat's filled prompt to `$RUN/<seat-label>/prompt.md`. Point at files instead of inlining large context (the **principle-guard-the-context-window** skill). Expand `$PSTACK` and `~` to absolute paths inside briefs, because a Codex seat does not know them. Codex seats know nothing about pstack skills, Claude Code tools, or this conversation, so every brief stands alone: goal, scope, file paths to read, how to verify, and the exact output shape.

## 3. Launch every seat of a step in one message

**`claude:<model>` and `inherit-parent`.** One Agent tool call per seat.

- `subagent_type`: what the calling skill names. Defaults: `read` mode uses `pstack:pstack-reader`. A read seat that needs MCP tools (the **why** investigators and synthesizer, the **reflect** reviewers) uses `general-purpose` and its brief says not to modify files. `write` mode uses `general-purpose`, and playbook code delegates use `pstack:poteto-agent`.
- `model`: the value after `claude:`. Omit it for `inherit-parent`.
- `prompt`: `Your brief is in <absolute path to prompt.md>. Read it in full and follow it. Reply with the output it asks for.`
- Run it in the background when the Agent tool offers that.

**`codex:<model>:<effort>`.** One Bash call per seat with `run_in_background: true` and a timeout that fits the work (read seats 1800000 ms, write seats up to 7200000 ms).

```bash
~/.claude/skills/pstack/scripts/codex-run --spec <value> --mode read|write \
  --prompt-file "$RUN/<seat>/prompt.md" --out "$RUN/<seat>" --cd <repo or worktree>
```

`--mode read` runs Codex in its read-only sandbox. `--mode write` runs it in `workspace-write`, which can write only inside `--cd`.

**Codex seats have no network and cannot write git.** Both Codex sandboxes block the network, and `workspace-write` keeps `.git` read-only. A Codex write seat edits files and nothing else: no commit, push, package install, `gh`, or posted verdict. The parent (or a Claude seat) reviews its diff and commits it. **Claude-only seats.** A seat runs as a Claude seat, whatever its role resolves to, when it must commit or push, open or comment on a PR, run `gh`, WebFetch or anything else on the network, use MCP tools, or start and drive the app (a live or verify lane through the **control-ui** or **control-cli** skill, which also runs servers). When its role resolves to `codex:*`, run it as `claude:opus`, in `write` mode with `subagent_type: general-purpose` in its own worktree when it starts processes, and say so.

**Parallel writers never share a checkout** (the **principle-separate-before-serializing-shared-state** skill). Give each write seat its own git worktree (`git worktree add <path> -b <branch>`). A Claude write seat gets `isolation: "worktree"` or its worktree path in the brief. A Codex write seat gets `--cd <worktree>`.

## 4. Wait for completion, then read

Completion is only the Agent tool's notification or the background Bash task ending (and `$RUN/<seat>/DONE` existing). Never sleep-poll and never guess that a seat finished.

When you must block on Codex seats (the Claude seats have returned, or the session gets no background notifications, as under `claude -p`), run `~/.claude/skills/pstack/scripts/codex-wait "$RUN/<seat>" ...` in the foreground with a Bash timeout above its `--timeout`. Do not hand-roll a sleep loop.

- Claude seat: its reply is the result.
- Codex seat: read `$RUN/<seat>/result.md`. `DONE` holds the exit code. On a non-zero code, read the tail of `stderr.log`. Never paste `events.jsonl` into the chat.

You own every seat's work. Read each result in full, check its claims against the code, and write your own synthesis. Do not pass a seat's summary through as yours.

## 5. Nested dispatch

A Claude Code subagent has no Agent tool, so it cannot spawn Claude seats. When a skill runs inside a subagent (a `poteto-agent` delegate running **how**, for example):

- `codex:*` seats still launch through `codex-run` with Bash.
- `claude:*` and `inherit-parent` seats run inline. Do that seat's work yourself in sequence, and say in the output that the seat ran inline.

A subagent also gets no completion notifications after its turn ends and cannot arm `/loop`. Whatever must wait on seats inside a subagent blocks with `codex-wait`. Long-lived loops (babysit, `/loop` ticks) stay in the root session.

Prefer keeping fan-out in the parent. A parent that knows a delegate will need a panel runs the panel itself before or after the delegate.

## 6. Fallbacks

Do not block a skill on a model problem. Fix the seat and say so in the output.

- A Codex seat fails to start or exits without `result.md` (CLI missing, not logged in, model rejected): rerun it once on the bundled default for that role's Codex seat (see `$PSTACK/templates/pstack-models.md`). If that also fails, run the seat as `claude:opus` and note "codex seat <label> fell back to claude:opus: <reason>".
- A Claude model is rejected: rerun on `opus` and say so.
- A seat drops out after a fallback: proceed with N-1 and record the dropout, as each skill describes.
