---
name: deslop
description: "Before commit, strip AI slop from the current diff: narrating comments, defensive code the codebase doesn't use, type escapes, needless wrappers, dead code, debug logs, off-style lines. Diff-scoped and behavior-preserving. Use for /deslop, 'deslop this', or the poteto-mode before-commit step."
disable-model-invocation: true
---

# Deslop

Clean the diff before it becomes a commit. Remove what an agent added that a careful engineer on this codebase would not have written. Change nothing else.

## Scope

The caller's files or diff. Otherwise the current diff against the base branch (default `main`), including staged, unstaged, and untracked files. Only lines this diff added or changed are in scope. Pre-existing code is out of scope even when it has the same smell.

## What to remove

Read each changed hunk next to the surrounding file. Judge every added line against how this file and its neighbors already work.

- **Narrating comments.** Comments that restate the code, label steps (`// Step 1`), or explain the edit (`// changed to fix X`). The **no-comments** skill handles the rest of the comments later.
- **Defensive code the codebase doesn't use.** Null checks on values the types or callers already guarantee, `try`/`catch` that swallows or rethrows unchanged, fallback defaults for impossible states, input validation deep inside trusted internals (the **principle-boundary-discipline** skill).
- **Type escapes.** `any`, `as unknown as`, non-null `!`, `@ts-ignore`, broad casts. Replace each with the real type or a narrowing. If no honest type exists, stop and report it.
- **Needless abstraction.** One-caller helpers, wrapper functions that only forward, config objects with one field, new files for a few lines (the **principle-laziness-protocol** skill).
- **Dead code.** Unused imports, variables, parameters, branches, exports, and commented-out code.
- **Leftover debugging.** `console.log`, `print`, `debugger`, temporary flags, scratch files.
- **Off-style lines.** Naming, error handling, logging, and idioms that differ from the rest of the file.

## Steps

1. Collect the scope (`git diff <base>...HEAD` plus `git diff` and `git status --porcelain` for the working tree).
2. Edit in place. Keep behavior identical. If removing something would change behavior, it is not slop. Leave it and say why.
3. Verify. Run the project's typecheck, lint, and the tests that cover the touched files. A deslop that breaks a check is reverted, not patched around.
4. Hand off. Before review, run the **no-comments** skill for the comment sweep.

**Reply:** what was removed, grouped by kind with file paths and counts, anything left on purpose with its reason, and the verification commands with their results.
