---
name: control-ui
description: "Drive a browser, web, or Electron UI the way a user does, to reproduce a bug or prove a change, and capture evidence from the real app. Use for /control-ui, UI repro, or the poteto-mode 'shipping UI' and bug-fix repro steps."
disable-model-invocation: true
---

# Control UI

Reproduce and prove UI behavior by driving the real app yourself. A screenshot of the real running app beats any claim about what the code should render.

## Pick the harness

1. **A project verify skill.** If `.claude/skills/verify-*/` exists for this app, use it. Its launch, doctor, and feature map win over anything below. If none exists and the app will be driven more than once, offer the **create-verification-skill** skill.
2. **The `playwright-cli` skill.** Default for web UIs. Scripted, repeatable, screenshots and traces.
3. **Playwright MCP tools** (`mcp__playwright__*`). Interactive snapshot, click, type, console, and network reads when exploring.
4. **The `terminal-browser` skill.** When the human should watch the page beside the conversation.
5. **The `claude-in-chrome` skill.** When the flow needs the user's real Chrome session (existing auth, extensions).
6. **Electron.** Launch with `--remote-debugging-port` and attach over CDP, or use Playwright's `_electron.launch`.

## Drive

- Start the app with its own dev command. Wait for a ready signal (log line or port answering), not a fixed sleep.
- Act through user-facing handles: roles, labels, visible text, `data-testid`. Not coordinates, not internal setters, not test-only routes.
- Reproduce before fixing. A bug you can't trigger yet is a hypothesis. Tighten conditions or instrument until it fires.
- After the fix, drive the same path again and compare.

## Evidence

Save to a directory you name in the reply (default `${TMPDIR:-/tmp}/pstack-evidence/<slug>/`).

- Screenshots of the action and the resulting state, before and after.
- Console errors and failing network requests from the same run.
- Side effects the UI implies (a request sent, a row written, a file saved), checked directly.

Clean up what you started (servers, browsers, profiles). Never kill by process name. Evidence survives cleanup.

**Reply:** the harness used, the steps driven, what was observed before and after, and the evidence paths.
