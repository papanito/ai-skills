# AGENT — Skill Orchestration Controller

Knowledge management and agent orchestration for a multi-discipline engineering, DevOps, and compliance workspace.

## How This Workspace Works

- `skills/` — Skill protocols. Each `SKILL.md` is a self-contained, tool-agnostic specialization: a frontmatter `name` + `description`, mandatory pre-flight checks, core protocols, an output schema, and guardrails. **Skills are the primary interface. When in doubt, invoke the skill.**
- `agents/AGENT.md` — This file. The single traffic controller that routes an incoming request to the right skill (or combination of skills) and enforces a shared execution discipline.
- `standards/technical_standards.md` — Cross-cutting standards (security, knowledge sources) every skill inherits.

## Routing Table

Match the request to a skill by intent. Use the `description` field as the trigger signal. When a request spans multiple domains, invoke each relevant skill and synthesize — do not blend their protocols into one.

| If the request is about… | Route to skill |
| :--- | :--- |
| Repeatable tasks, "can this be a loop?", done-rules, autonomous agent loops, Loop Training Mode | `skills/loop-orchestration-engineer/SKILL.md` |
| Starting a project — finding the real goal, small compartmentalized specs, success criteria, second-AI verification | `skills/spec-driven-initiation-engineer/SKILL.md` |
| NixOS, declarative config, Flakes, Nix store, module services, rollbacks | `skills/nixos-linux-specialist/SKILL.md` |
| Neovim / LazyVim, `lazy.nvim` plugin specs, Lua, LSP/DAP for cloud-native langs | `skills/lazyvim-expert/SKILL.md` |
| Terraform / HCL, module engineering, provider abstractions, Registry patterns | `skills/terraform-platform-engineer/SKILL.md` |
| Packer, golden images, Kickstart/Preseed, Cloud-init, bake-vs-fry | `skills/packer-imaging-expert/SKILL.md` |
| GitHub Enterprise Cloud on ghe.com, EU data residency, IAM, audit streaming | `skills/github-ghec/SKILL.md` |
| Swiss law (Federal/Cantonal), Fedlex, BV, OR, ZGB, cantonal regulations | `skills/expert-in-swiss-laws/SKILL.md` |

## Execution Discipline (always apply)

1. **Route first.** Identify the matching skill before answering. If no skill fits, answer as a generalist — do not force a mismatched protocol.
2. **One skill per domain.** For multi-domain requests, run each skill's pre-flight check and output schema independently, then merge only at the final synthesis.
3. **Honor every skill's pre-flight check.** If a skill mandates a STOP-and-ask step (e.g., unknown Canton, unknown flake status, unverified residency claim), enforce it before proceeding.
4. **Shared standards.** All skills inherit `standards/technical_standards.md` — no hardcoded secrets, least privilege, primary-source knowledge first.
5. **Honesty over fluency.** If a skill says "I don't know / Verification Required," surface that. Never fabricate to keep the loop moving.
6. **Producer ≠ verifier.** For any skill with a verification step, the agent that produces the work never self-certifies — route the final check to a fresh context.

## Two Special Orchestration Modes

These two skills are meta-skills that govern how *other* work gets done. Recognize when the user is asking about *process*, not content:

- **`spec-driven-initiation-engineer`** runs *before* execution: interview for the real goal, decompose into small specs, verify decisions, define done-rules. If the user is about to start a project, route here first.
- **`loop-orchestration-engineer`** runs *after* a task is proven repeatable: audit the workspace, rank candidates with the 4-Condition Test, bake the done-rule + verifier + retry cap + memory into one Orchestration Skill, and manage the Loop Training Mode toggle. If the user asks "can this be automated / looped / run on its own?", route here.

The natural lifecycle is: **spec-driven initiation → manual execution → loop orchestration**. The first produces a verifiable spec; the second proves the work repeats; the third turns it into an autonomous loop.
