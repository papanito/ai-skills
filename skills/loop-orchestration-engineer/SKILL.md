---
name: loop-orchestration-engineer
description: specialized protocol for Loop Engineering — auditing a workspace for repeatable tasks, ranking them with the 4-Condition Test, and building self-verifying Loop Orchestration Skills with a done-rule, a separate verifier subagent, run memory, and a Loop Training Mode toggle.
---

# loop-orchestration-engineer

## GOAL

Turn repeatable, rule-decidable tasks into self-verifying **Loop Orchestration Skills** runnable with one command. Each loop bakes in: goal, fixed steps, done-rule, separate verifier, retry cap, memory log.

## 4-CONDITION TEST

A task MUST pass all four before becoming a loop:

1. **Repeats** — recurs (weekly, per-PR, on-trigger).
2. **Rule-decidable done** — a rule objectively confirms completion.
3. **Affordable waste** — user tolerates a few failed runs.
4. **Has data + tools** — AI has the files, context, and tool access.

Rank by how cleanly they pass. Only suggest loops with an existing SKILL.md (or user ready to author one).

## ORCHESTRATION SKILL ANATOMY

Static, readable in one sitting:

1. **Loop Training Mode toggle** — `ON` (default) or `OFF`.
2. **Goal** — one sentence: what "done" looks like.
3. **Steps** — fixed sequence.
4. **Done-rule** — machine-checkable completion rule.
5. **Verifier spec** — separate subagent, fresh context, scores 1–10, threshold for "done".
6. **Retry cap** — max re-runs of a failing step before abort.
7. **Memory contract** — two files per run: output + memory log.

### Loop Training Mode

- **ON (default):** pause at every step for approval. Skip passing steps. Only re-run failures. Respect retry cap.
- **OFF:** run autonomously, keep done-rule checks and retry cap.
- Promote to OFF after N consecutive successful runs.

## PROTOCOLS

1. **Audit & rank:** Read workspace, history, tools, saved skills. Run 4-Condition Test per candidate. Output ranked table, name the strongest.
2. **Build:** Interview for task, goal, done-rule. Emit one Orchestration Skill with all 7 elements pre-baked. Keep it static.
3. **Verify:** Final verification runs in a separate subagent (fresh context). Scores 1–10, done only above threshold.
4. **Memory:** Write output file + memory file (what happened, worked, failed, remember next run).
5. **Promote:** After N successful runs with ON, flip to OFF. Keep done-rule and retry cap.

## OUTPUT SCHEMA

1. **TL;DR** — one-line summary.
2. **4-Condition Test results** — pass/fail per condition, ranked table.
3. **Orchestration Skill** — complete file with all 7 elements.
4. **Verification spec** — scoring and threshold.
5. **Next action** — single concrete step.

## GUARDRAILS

- **One loop, one skill.** No bundling unrelated tasks.
- **No done-rule, no loop.** Machine-checkable or rejected.
- **Retry cap non-negotiable.** Never loop forever.
- **Producer ≠ verifier.** Never score own output.
- **Static skill.** Readable artifact, not per-run prose.
- **Honesty.** Failing any condition = "not a loop candidate."
