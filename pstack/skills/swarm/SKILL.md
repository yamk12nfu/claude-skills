---
name: swarm
description: "Fan out N parallel workers, drain them, and return one report. Use for /swarm, 'swarm this', or parallel coverage, races, gauntlets, and exploration."
disable-model-invocation: true
---

# Swarm

Fan out N parallel background workers. They may cover separate slices, race the same brief, or mix both. The parent waits, aggregates, and returns one report.

## Start

Open a todolist (the task list, per `~/.claude/skills/pstack/references/todo.md`) with one entry per phase before launching anything.

1. Frame
2. Fan out
3. Aggregate
4. Report

## Phase A: Frame

1. State the done predicate and the artifact or report the swarm must return.
2. Choose the shape. Partition into slices, race N workers on identical briefs, or mix both. For a race or mixed shape, declare `first pass`, `rank all`, or `best-of` before spawning.
3. Set N from the user or derive it from the shape. N is total workers, not a concurrency limit.
4. Pick the worker model from the `swarm workers` role. Resolve it and launch seats per `~/.claude/skills/pstack/references/dispatch.md`. For a model race, name each arm's value (`claude:<model>` or `codex:<model>:<effort>`) up front.
5. Give each worker its own writable output when it writes. A writing worker gets its own git worktree. When workers verify or measure commits, each brief names the exact SHAs. A measurement brief also names the method (sample count, what one sample is, order). The worker records both in its result.

## Phase B: Fan out

Launch all N workers in one message per dispatch.md, on the step 4 value. A worker that only reads or measures runs in `read` mode. A worker that edits runs in `write` mode (`subagent_type: general-purpose` for a Claude seat) inside its own git worktree. A Codex worker gets the worktree as `--cd`. A Claude worker gets `isolation: "worktree"` or the worktree path in its brief. A worker that starts or drives the app, needs network or `gh`, or commits runs as a Claude `general-purpose` write seat in its own worktree whatever step 4 resolved (Claude-only seats in dispatch.md).

When a worker must start from a non-default branch, create its worktree checked out at that branch (`git worktree add <path> <branch>`).

Every brief stands alone. Include the goal, scope, exact slice or race arm, how to verify, and what to report. Reports use `PASS`, `ISSUES`, or `BLOCKED` with evidence. A worker that can prove a defect reports `ISSUES` and lists every issue it can prove, not only the first.

If a worker drops out, proceed with N-1 and note it.

## Phase C: Aggregate

Read the terminal results. Drop a result that does not record the SHAs and method its brief names, and respawn that worker once. After a second miss, record a gap. A gap does not count as a pass. For coverage, every required slice needs a result. For a race, apply the selection rule declared up front. Use first pass, rank all, or best-of. Do not paste raw worker dumps.

Keep a compact result table, one-line evidenced issues, and explicit gaps or dropouts.

## Phase D: Report

Return one consolidated in-chat report with the table, issue one-liners, gaps or dropouts, and the race rule when used.
