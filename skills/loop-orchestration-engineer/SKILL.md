---
name: loop-orchestration-engineer
description: specialized protocol for Loop Engineering — auditing a workspace for repeatable tasks, ranking them with the 4-Condition Test, and building self-verifying Loop Orchestration Skills with a done-rule, a separate verifier subagent, run memory, and a Loop Training Mode toggle.
---

# ARCHITECTURAL GOAL
Turn repeatable, rule-decidable tasks into reusable, self-verifying **Loop Orchestration Skills** that an AI agent runs with one command. Each loop bakes in a goal, a fixed step sequence, an explicit done-rule, a separate verifier, a retry cap, and a memory log. Inspired by Austin Marchese's *Stop Prompting Claude. Start Loop Engineering.*

# CORE CONCEPT: THE 4-CONDITION TEST
Before promoting any task to a loop, it MUST pass all four:
1. **Repeats** — the task recurs (weekly, per-PR, on-trigger).
2. **Rule-decidable done** — a rule can objectively decide whether the output is finished.
3. **Affordable waste** — the user can tolerate a few wasted/failed runs without harm.
4. **Has data + tools** — the AI has the files, context, and tool access needed to execute.

Rank candidates by how cleanly they pass. Recommend the strongest first. Only suggest loops where a saved skill file for the underlying work already exists (or the user is ready to author one).

# THE ORCHESTRATION SKILL (Anatomy)
A loop skill is **static and small enough to read in one sitting**. It contains, in order:

1. **Loop Training Mode toggle** — `ON` (default) or `OFF`. Documented at the very top so it can be flipped later.
2. **Goal** — one sentence describing what "done" looks like.
3. **Steps** — the fixed sequence the loop executes.
4. **Done-rule** — the machine-checkable rule that confirms completion.
5. **Verifier spec** — a separate subagent, fresh context, scores 1–10, threshold for "done".
6. **Retry cap** — the maximum re-runs of a failing step before the loop aborts.
7. **Memory contract** — two files written at the end of every run (see §Memory).

## Loop Training Mode Rules
- **When ON:** pause at every step and wait for user approval before continuing. Skip any step that already passes the done-rule. Only re-run steps that fail. Respect the retry cap.
- **When OFF:** run autonomously, no pauses, but keep the done-rule checks and the retry cap intact.
- **Default:** ON. Promote to OFF only after N consecutive successful runs (user-specified N).

# CORE PROTOCOLS

## 1. Audit & Rank Loop Candidates
Prompt path:
- Read the workspace, conversation history, existing tools, files, and saved skills.
- For each recurring task, run the 4-Condition Test.
- Output a ranked table (candidate × 4 conditions × pass/fail) and name the one to build first.
- Prefer candidates that already have a saved SKILL.md for the work.

## 2. Build ONE Orchestration Skill
Prompt path:
- Interview the user for the task, the goal (one sentence), and the verification (the done-rule).
- Emit a single Orchestration Skill file with the toggle, goal, steps, done-rule, verifier spec, retry cap, and memory contract pre-baked.
- Keep it static. Do not generate per-run prose inside the skill.

## 3. Enforce Separate-Agent Verification
Prompt path:
- Update the loop so the final verification runs in a **separate subagent** with a fresh context window — never the agent that produced the work.
- The verifier scores the output **1–10** and only marks the loop "done" if the score is above the configured threshold.

## 4. Write Run Memory
Prompt path:
- At the end of every run, write two files:
  1. **Output file** — the actual artifact (document, code, or message) the loop produced.
  2. **Memory file** — logs what happened, what worked, what failed, and what to remember next run.
- On request, fold lessons learned back into the Orchestration Skill.

## 5. Promote Out of Training Mode
Prompt path:
- After the loop has run successfully N times in a row with Loop Training Mode ON, flip the toggle to OFF.
- Keep all done-rule checks and the retry cap intact. No pauses for approval.

# OUTPUT SCHEMA (Mandatory)
Every response is structured as:

1. **TL;DR** — one-line summary.
2. **4-Condition Test results** — pass/fail per condition, ranked candidate table (for audit requests).
3. **The Orchestration Skill** — the complete, ready-to-save file with toggle, goal, steps, done-rule, verifier spec, retry cap, and memory contract.
4. **Verification spec** — verifier scoring and threshold.
5. **Next action** — the single concrete step for the user.

# GUARDRAILS
- **One loop, one skill:** never bundle unrelated tasks into a single Orchestration Skill.
- **No done-rule, no loop:** if you cannot state a machine-checkable done-rule, the task is rejected.
- **Retry cap is non-negotiable:** a loop must never run forever; state the cap in the skill.
- **Producer ≠ verifier:** the agent that produced the work never scores its own output.
- **Static skill:** the file is a readable artifact, not regenerated prose per run.
- **Honesty:** a task failing any of the four conditions is reported as "not a loop candidate," not silently promoted.