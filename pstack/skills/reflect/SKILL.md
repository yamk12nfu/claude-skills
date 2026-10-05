---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
disable-model-invocation: true
---

# Reflect

Mine the current conversation for durable learnings, then route them into skill edits.

## When to invoke

Invoke when the user says "reflect" or "/reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## Process

### 1. Locate the active transcript

The parent finds its own transcript file before fanning out. Claude Code stores the active project's transcripts in `~/.claude/projects/<slug>/`, where `<slug>` is the absolute working directory with every non-alphanumeric character replaced by `-`. The current session id is `${CLAUDE_SESSION_ID}`, so the transcript is usually `~/.claude/projects/<slug>/${CLAUDE_SESSION_ID}.jsonl`. Use that directory only. Do not glob across `~/.claude/projects/*/`. That crosses workspace boundaries and reads private chats from unrelated projects.

```bash
slug="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; slug="$(printf %s "$slug" | sed 's#[^A-Za-z0-9]#-#g')"
ls -t ~/.claude/projects/"$slug"/*.jsonl ~/.claude/projects/"$slug"/*/subagents/*.jsonl 2>/dev/null | head -10
```

Two transcript layouts: session (`<session-id>.jsonl`) and subagent (`<session-id>/subagents/agent-<id>.jsonl`). Codex seats' transcripts live in `~/.codex/sessions/` and the seat directories under the run directory (`prompt.md`, `result.md`).

If `${CLAUDE_SESSION_ID}` was not substituted (this file was opened with Read), use `$CLAUDE_CODE_SESSION_ID` from Bash. If that is empty too, check candidates instead. Find the first user-message line in each (`"type":"user"`) and check that it contains the conversation's opening user prompt. Take the matching path. If no path resolves, write a tight digest of the session and pass that instead.

### 2. Spawn three reviewers in parallel

One message, three seats. Each reviewer and the synthesizer name a role line in the pstack-models rule. Resolve each role and launch its seat per `~/.claude/skills/pstack/references/dispatch.md`, in `read` mode with `subagent_type: general-purpose` for a Claude seat. Reviewers need MCP access for context lookups (tickets, chat threads, observability traces referenced in the transcript), and `pstack:pstack-reader` has no MCP tools. The templates already forbid writes. A Codex seat sees only the MCP servers in `~/.codex/config.toml`, and its read-only sandbox can still read the transcript path.

| Lens | Role line | Prompt template |
|---|---|---|
| Judgment | `reflect judgment, divergent, synthesizer` | `~/.claude/skills/pstack/skills/reflect/references/judgment-reviewer.md` |
| Tooling | `reflect tooling` | `~/.claude/skills/pstack/skills/reflect/references/tooling-reviewer.md` |
| Divergent | `reflect judgment, divergent, synthesizer` | `~/.claude/skills/pstack/skills/reflect/references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Claude reviewers return findings in their reply. Codex reviewers return them in the seat's `result.md`.

### 3. Synthesize

One seat on the `reflect judgment, divergent, synthesizer` role, `read` mode with `subagent_type: general-purpose` for a Claude seat. The synthesizer's quality check includes spot-verifying citations, which can require MCP access, and `pstack:pstack-reader` has no MCP tools. Use `~/.claude/skills/pstack/skills/reflect/references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. The synthesizer returns a structured Accepted / Rejected / Backlog list.

### 4. Structural enforcement check

Sanity-check the synthesizer's Accepted list. For any item that would be enforced more reliably by a lint rule, script, metadata flag, or runtime check, move it from Accepted to Backlog. See the **encode-lessons-in-structure** principle skill.

### 5. Apply

Before applying any Accepted edit, present the synthesizer's full Accepted/Rejected/Backlog output to the user and wait for explicit approval. The user picks which subset to apply and may redirect routings. Skill changes affect every future agent in the org. Do not auto-apply.

Backlog items file to whatever devex / backlog tracker your team uses automatically. Only the Accepted list waits for approval.

For each approved Accepted item, follow the Routing field exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): parent does directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): hand to the `skill-creator` skill (Anthropic's skill authoring skill) and run its draft / test / iterate loop. If it is not available, run that loop by hand.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): hand to `skill-creator` and run its description-optimization loop.
- `new skill via skill-creator: <kebab-name>`: hand creation to `skill-creator`. Do not invent the shape ad hoc.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done. Skip this step if it doesn't.

### 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
