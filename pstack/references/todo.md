# Todo list

Cursor shows pstack's todolist in its UI. On Claude Code the same list is the task list (`TaskCreate`, `TaskUpdate`, `TaskList`). Every "open a todolist" in pstack means this file.

## With the task tools (sessions started with `claude-pstack`)

1. Before any other work, create one task per item with `TaskCreate`. For a playbook, run `~/.claude/skills/pstack/scripts/pstack-playbook <name>` (names: `--list`) and use each line it prints, `<n>. <title>`, verbatim as one task's subject, in order, then add the task-specific items. The script also records the playbook for this session, and the hooks check that every step number has a task. For a skill (arena, architect, swarm, figure-it-out), the items are its phases.
2. A step you choose not to do still gets its task, titled `<n>. skip: <reason>`, and is marked completed at once. Sizing the task as small is a reason you write down, never a silent skip. If the task grows, revisit the skips.
3. Mark a task `in_progress` with `TaskUpdate` when its step starts and `completed` when its check passes. Exactly one task is in progress at a time. Never mark a task completed on a self-report or a skipped check.
4. New work found mid-run becomes a new task in the place it runs, not a silent detour.

## Without them

If the session has no `TaskCreate` tool, it was started with plain `claude`. Say once, in one line, that `claude-pstack` (or `claude-pstack --resume`) shows the task panel. Then write the list to the file `~/.claude/skills/pstack/scripts/sticky-reminder todo-path` prints, as `- [ ]` lines, tick items as they close, and restate the open items in each reply.

Under poteto-mode, hooks enforce this. File edits in the main thread are blocked until the list exists, holds every step number of the recorded playbook, and has a task in progress. Ending a turn with a missing step, or with finished steps still open, is sent back once. Each user turn's reminder lists the open items.
