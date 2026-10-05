---
name: setup-pstack
description: Configure which models pstack uses per role (Claude subagents or Codex CLI) and at what reasoning budget. Detects your available models and writes an always-loaded rule that overrides the skill defaults. Use for /setup-pstack, "configure pstack models", "pstack budget", or changing pstack's model choices.
disable-model-invocation: true
---

# Setup pstack

Write `~/.claude/rules/pstack-models.md`, an always-loaded rule that sets pstack's model per role. Claude Code loads every file in `~/.claude/rules/` into each new session.

Each role value is `claude:<model>`, `codex:<model>:<effort>`, `inherit-parent`, or `auto`. The grammar and the dispatch rules are in `~/.claude/skills/pstack/templates/pstack-models.md` and `~/.claude/skills/pstack/references/dispatch.md`.

## Steps

### 1. Detect available models

- **Claude.** The Agent tool accepts `fable`, `opus`, `sonnet`, and `haiku`. Treat those four as detected.
- **Codex.** Run `codex --version` and `codex login status`. If either fails, Codex is unavailable. Say so, and every `codex:*` role needs a Claude choice. Otherwise read the slugs and their effort ladders from Codex's model cache:

```bash
python3 -c 'import json,os; d=json.load(open(os.path.expanduser("~/.codex/models_cache.json")))
for m in d["models"]:
    if m.get("visibility")=="list": print(m["slug"], [x["effort"] for x in m.get("supported_reasoning_levels",[])])'
```

If the cache is missing, ask the user to paste the Codex model slugs they can use. Never write a slug you have not confirmed. `inherit-parent` and `auto` are always valid.

### 2. Load current state

The default role-to-model mapping is the fenced block in `~/.claude/skills/pstack/templates/pstack-models.md`. If `~/.claude/rules/pstack-models.md` exists, read it and treat its `# budget` line and role values as the current choices. Otherwise start from the defaults. A line whose role is not in the defaults is from a retired role. Drop it.

If `~/.cursor/rules/pstack-models.mdc` exists, mention it once. Its `claude-*` and `gpt-*` choices hint at the user's preferences, but its slugs are Cursor's, so never copy one verbatim.

### 3. Budget, map, and confirm

**(a) Ask for a budget.** Use `AskUserQuestion` with these four options and exact labels, naming the current budget when the rule records one.

- `unlimited — keep max`
- `large — xhigh reasoning`
- `medium — high reasoning`
- `small — medium reasoning`

**(b) Apply it.** Build the working table from the defaults, and on a re-run keep any role the user changed by model, list, or alias. The budget sets the effort token of every `codex:*` value, panel entries included, to `max`, `xhigh`, `high`, or `medium` on the ladder `max` > `xhigh` > `high` > `medium` > `low`. If a Codex model's ladder lacks the target, use its highest effort at or below the target. `claude:*` values have no per-seat effort knob, so the budget leaves them alone. Under `small`, suggest `claude:sonnet` for the `how explorer` and `why investigators` roles, and leave the choice to the user.

**(c) Show the roles and confirm.** Show every role with its value, marking any value whose model was not detected as needing a choice. List each line step 2 dropped. Ask with `AskUserQuestion` whether to accept as-is or change specific roles. `AskUserQuestion` takes at most four options per question, so for each role to change ask the family first (`claude`, `codex`, `inherit-parent`), then the model within it, offering the most likely models and letting the free-text answer cover the rest. Panel roles (`arena runners`, `architect runners`, `interrogate reviewers`) take a list, one seat per entry, so the list length sets the fan-out. `arena cross-judge pool` is also a list, but arena picks one value from it, preferring a `codex:*` value so the judge's family differs from the Claude parent. `swarm workers` is the default for every worker unless a race assigns a model per arm. Recommend keeping both families on every panel. Model diversity is where the adversarial signal comes from.

### 4. Validate

Every `claude:*` model is one of the four aliases. Every `codex:*` model is a detected slug, and its effort is on that slug's ladder. `inherit-parent` and `auto` always pass. If a value fails, stop and ask again.

### 5. Write the rule

Copy `~/.claude/skills/pstack/templates/pstack-models.md` to `~/.claude/rules/pstack-models.md` (create the directory if needed), then replace the fenced `pstack-models` block with the chosen `# budget` line (label and target effort) and one line per role, using the same labels. Overwrite the whole file so re-runs stay idempotent.

### 6. Prove it

Run `~/.claude/skills/pstack/scripts/pstack-model --list` and confirm every role prints the value you wrote. Then ping each distinct Codex model once, in parallel, at `low` effort.

```bash
P="${TMPDIR:-/tmp}/pstack-setup"; mkdir -p "$P"; echo "Reply with the single word ok." > "$P/ping.md"
~/.claude/skills/pstack/scripts/codex-run --spec codex:<model>:low --mode read --prompt-file "$P/ping.md" --out "$P/<model>"
```

A ping whose `DONE` is not `0` means that model is unusable here. Show the `stderr.log` tail and go back to step 3 for its roles.

### 7. Confirm

Tell the user the rule was written, that it applies to new sessions, and which Codex models answered the ping. Re-running this skill updates it.

### 8. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill under `.claude/skills/`, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with /create-verification-skill." On yes, run the **create-verification-skill** skill (`~/.claude/skills/pstack/skills/create-verification-skill/SKILL.md`). On no, move on without pushing.
