# Global Directory Hierarchy

All repositories live under `~/Projects/`, organized by forge domain or organization.
The `wyssmann` directory supports both direct standalone projects (e.g. `eventcompass`)
and subgroup hierarchies (e.g. `terraform/`, `documents/`).

This layout is shared across skills. The `wt/` worktree roots shown below are managed
by the worktrunk (`wt`) strategy — see
[skills/git-worktree-management/SKILL.md](../skills/git-worktree-management/SKILL.md)
for global git ignore setup, `config.toml`, and workflows.

```text
~/Projects/
├── github.com/                       # Public/Forked GitHub repos
│   └── <upstream_owner>/<project>/
│       ├── .git/                     # Main clone (main/master branch)
│       └── wt/                       # Worktree root (globally ignored)
│           └── feature-auth/         # Worktree (Branch: papanito/feature-auth)
│
├── gitlab.com/                       # Public/Forked GitLab repos
│   └── <upstream_owner>/<project>/
│       └── wt/
│
├── papanito/                         # Personal projects
│   └── <project>/
│       └── wt/
│
├── playground/                       # Scratchpad & experimental code
│   └── <project>/
│       └── wt/
│
└── wyssmann/                         # Private work & organization
    ├── eventcompass/                 # Direct project repo under organization
    │   └── wt/                       # Worktrees (e.g., wt/add-auth)
    ├── terraform/                    # Subgroup for IaC modules/stacks
    │   └── <module_or_stack>/
    │       └── wt/
    └── documents/                    # Subgroup for documentation repos
        └── <doc_repo>/
            └── wt/
```
