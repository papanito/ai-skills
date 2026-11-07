---
name: worktrunk-strategy
description: Directory hierarchy, global git ignore setup, and worktrunk (wt) configuration for managing worktrees across github.com, gitlab.com, papanito, playground, and wyssmann (subgroups & direct projects like eventcompass).
---

# Multi-Group Worktrunk & Worktree Strategy

This skill governs the directory structure, global git rules, and `worktrunk` (`wt`) configuration for managing repos across multiple platforms, subgroups, standalone projects, and private domains.

## 1. Global Directory Hierarchy

The global directory layout — `~/Projects/` organized by forge domain (`github.com`, `gitlab.com`) and organization (`papanito`, `playground`, `wyssmann` incl. subgroups) — is defined in the shared standard [standards/directory-hierarchy.md](../../standards/directory-hierarchy.md). Sections 2–4 below configure worktrunk for that layout.

## 2. Global Git Ignore Setup

Because `wt/` is ignored globally in your Git environment, you **do not** need to edit or touch `.gitignore` inside individual repositories or upstream forks.

### Step 1: Configure Global Ignore File

Ensure your global gitignore file points to `~/.config/git/ignore` (or `~/.gitignore_global`):

```bash
git config --global core.excludesfile ~/.config/git/ignore
mkdir -p ~/.config/git
```

### Step 2: Add Worktree Directory Rule

Append `/wt/` to your global ignore file:

```gitignore
# ~/.config/git/ignore

# Ignore Worktrunk worktree root across all repositories
/wt/
```

## 3. Worktrunk Configuration (`config.toml`)

`worktrunk` resolves paths relative to the root of the active Git repository. Setting `path_template` ensures feature worktrees sit in `/wt/` regardless of whether the repo is at `wyssmann/eventcompass` or deeply nested inside `wyssmann/terraform/modules/vpc/`.

### Configuration Path

* **Linux / XDG:** `~/.config/worktrunk/config.toml`
* **macOS:** `~/Library/Application Support/worktrunk/config.toml`

```toml
# User Configuration for Worktrunk (wt)

[worktree]
# Automatically prefix feature branches created via wt with 'papanito/'
branch_prefix = "papanito/"

# Route worktree directories into the globally-ignored local 'wt/' directory
# Strips the 'papanito/' prefix from the directory name for cleaner paths
path_template = "wt/{{ branch | remove_prefix: 'papanito/' }}"
```

## 4. Operational Resolution Matrix

Regardless of directory depth, `wt` creates branches and resolves paths dynamically:

| Target Repo Directory | Executed Command | Created Git Branch | Resolved Worktree Path |
| :--- | :--- | :--- | :--- |
| `~/Projects/wyssmann/eventcompass` | `wt switch -c auth` | `papanito/auth` | `~/Projects/wyssmann/eventcompass/wt/auth` |
| `~/Projects/wyssmann/terraform/aws-vpc` | `wt switch -c subnets` | `papanito/subnets` | `~/Projects/wyssmann/terraform/aws-vpc/wt/subnets` |
| `~/Projects/papanito/blog` | `wt switch -c new-post` | `papanito/new-post` | `~/Projects/papanito/blog/wt/new-post` |
| `~/Projects/github.com/cli/cli` | `wt switch -c fix-bug` | `papanito/fix-bug` | `~/Projects/github.com/cli/cli/wt/fix-bug` |

## 5. Standard Workflow Commands

```bash
# Create a worktree and switch into it
wt switch --create feature-name

# List active worktrees for the current repo
wt list

# Merge feature branch back into main branch and clean up worktree folder
wt merge papanito/feature-name

# Remove worktree without merging
wt remove feature-name
```
