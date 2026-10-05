# pstack model configuration

pstack (Claude Code + Codex port) reads this file to pick a model per role. `/setup-pstack` writes it to `~/.claude/rules/pstack-models.md`. Delete a role line to fall back to the default in `~/.claude/skills/pstack/templates/pstack-models.md`.

Value grammar, one value per seat, comma-separated for panels:

- `claude:<model>` runs the seat as a Claude Code subagent (Agent tool, `model: <model>`). `<model>` is `fable`, `opus`, `sonnet`, or `haiku`.
- `codex:<model>:<effort>` runs the seat through Codex CLI (`codex exec`) via `~/.claude/skills/pstack/scripts/codex-run`. `<effort>` is `low`, `medium`, `high`, `xhigh`, or `max`.
- `inherit-parent` or `auto` runs the seat as a Claude Code subagent on the parent model (omit `model`). Alias entries in a panel still count toward its fan-out.

Resolve a role with `~/.claude/skills/pstack/scripts/pstack-model "<role>"`. Dispatch each printed value per `~/.claude/skills/pstack/references/dispatch.md`. In pstack files, `$PSTACK` means `~/.claude/skills/pstack`.

```pstack-models
# budget: unlimited (max)
feature, refactoring: codex:gpt-6-luna:max
bug-fix: codex:gpt-6-luna:max
perf-issue: codex:gpt-6-luna:max
hillclimb: codex:gpt-6-luna:max
judgment and prose: claude:fable
hardest tasks: claude:fable
how explorer: claude:opus
how explainer: claude:fable
why investigators: claude:opus
why synthesizer: claude:fable
reflect tooling: codex:gpt-6-luna:max
reflect judgment, divergent, synthesizer: claude:fable
arena runners: claude:fable, claude:opus, codex:gpt-6-astra:max, codex:gpt-6.1-sol:max
arena cross-judge pool: claude:fable, codex:gpt-6-astra:max, codex:gpt-6.1-sol:max
swarm workers: codex:gpt-6-luna:max
recall miners: claude:haiku
architect runners: claude:fable, claude:opus, codex:gpt-6-astra:max, codex:gpt-6.1-sol:max
interrogate reviewers: claude:fable, claude:opus, codex:gpt-6-astra:max, codex:gpt-6.1-sol:max
```
