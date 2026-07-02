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
7. **Commit on completion.** After finishing a task, if the workspace is a git repository (`.git/` exists), commit the changes:
   - **Pre-commit installed?** Check for `.pre-commit-config.yaml` and `.git/hooks/pre-commit`. If both exist, hooks are already active — do NOT disable them. If `.pre-commit-config.yaml` exists but `.git/hooks/pre-commit` is missing, run `pre-commit install` and `pre-commit install --hook-type commit-msg` to enable both the pre-commit and commit-msg hooks.
   - **Commit message format.** Check for a commitlint config first (`.commitlintrc*`, `commitlint.config.*`, a `commitlint` key in `package.json`, OR a `commitlint` hook in `.pre-commit-config.yaml`). If found, follow its rules exactly (type, scope, subject, body, footer). The commit-msg hook will enforce this on commit.
   - **No commitlint config? Follow the existing pattern.** Inspect `git log --oneline` for the established convention and match it (type, scope, tense, casing).
   - **Default fallback — Conventional Commits.** If neither a config nor prior history exists, use `type(scope): subject` with a lowercase imperative subject under 72 characters. Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `style`, `perf`, `build`, `ci`.
   - **Stage only files changed by this task** — do not bulk-add unrelated working-tree changes. Use `git add` on the specific files you created or modified.
   - **Verify before committing.** Run `git status` to confirm only intended files are staged, then commit. If pre-commit hooks fail, fix the reported issues and re-stage — never bypass hooks with `--no-verify`. Never amend or force-push unless explicitly asked.

## Two Special Orchestration Modes

These two skills are meta-skills that govern how *other* work gets done. Recognize when the user is asking about *process*, not content:

- **`spec-driven-initiation-engineer`** runs *before* execution: interview for the real goal, decompose into small specs, verify decisions, define done-rules. If the user is about to start a project, route here first.
- **`loop-orchestration-engineer`** runs *after* a task is proven repeatable: audit the workspace, rank candidates with the 4-Condition Test, bake the done-rule + verifier + retry cap + memory into one Orchestration Skill, and manage the Loop Training Mode toggle. If the user asks "can this be automated / looped / run on its own?", route here.

The natural lifecycle is: **spec-driven initiation → manual execution → loop orchestration**. The first produces a verifiable spec; the second proves the work repeats; the third turns it into an autonomous loop.
