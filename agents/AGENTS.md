# Working Path Discipline (non-negotiable)

Edit ONLY in version-controlled source — never in symlink targets or runtime dirs:

| Artifact | Edit in | Not in |
| :--- | :--- | :--- |
| Skills, task agents, `AGENTS.md`, `link_resources.sh` | `ai-skills/` repo | `~/<agent dir>/agent/` (symlinks) |
| Dotfiles (nvim, home-manager, omp config) | `~/.local/share/chezmoi/` | `~` (chezmoi target) |

# Routing contract

1. **Route first.** Match by skill `description`. No skill fits? Answer as generalist.
2. **One skill per domain.** Run each independently, merge at synthesis.
3. **Honor pre-flight checks.** If a skill mandates STOP-and-ask, enforce it.
4. **Shared standards.** All skills inherit `standards/technical_standards.md`. Repositories live under the global directory layout in `standards/directory-hierarchy.md` (forges & organizations under `~/Projects/`) — resolve repo paths and worktree roots (`wt/`, worktrunk) against that hierarchy.
5. **Honesty over fluency.** Surface "I don't know / Verification Required." Never fabricate.
6. **Producer ≠ verifier.** Never self-certify — route final checks to a fresh context.
7. **Commit on completion.** Follow `standards/technical_standards.md` (§3): detect hooks, match commit format (commitlint → existing pattern → Conventional Commits), stage only task files, never `--no-verify`.
8. **GitLab**: Follow `standards/gitlab.md`

# Conventions

- **Repository workflow:** All development repos use a **bare clone + worktrees** workflow. The bare repo lives at `~/Projects/papanito/<repo>.git` (canonical, never work in it directly). A base dir at `~/Projects/papanito/<repo>/` contains all worktrees — one subdir per branch, named after the branch with `/` replaced by `-` (e.g. `main/`, `feature-seat-planner/`, `papanito-experiment/`). Branch names are always prefixed with `feature/` or `papanito/`. See `standards/technical_standards.md` §3 for the full workflow.
- **Design templates (mandatory):** Always use the templates in `~/Projects/wyssmann.com/documents/design/templates` as the basis when starting, building, or restructuring frontend applications (e.g. `app-template` for web applications). Never invent a bespoke layout, styling scheme, or ad-hoc architecture from scratch — adopt the template's structure, shared shell components (`AppHeader`, `PrimaryNavBar`, `ViewBar`, `AppFooter`), Tailwind 4 `@theme` palette, typography rules, and EventCompass styleguide.
- **Cross-repo spec work (shared design-system package):** Specs, plans and tasks for behaviour that lives in the shared `@wyssmann/design-system` package are written in the consuming repo's `.specify/` (e.g. `eventgenie`), but the implementation happens in `~/Projects/wyssmann.com/design-system` per that repo's `AGENTS.md` — including its own tests, which own the behaviour. The app consumes a package *release* (tag-driven CHANGELOG, GitLab group npm registry) by bumping the version and committing the lockfile; never patch package behaviour in app-local copies, node_modules or vendored source. When a cite in an issue/spec predates an element's move into the package, verify the current source there first.
