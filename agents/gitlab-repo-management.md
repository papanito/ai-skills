# GitLab Repository Management via Terraform

## Overview

Repositories are managed with Terraform, not the GitLab UI or CLI. The Terraform project lives at `https://gitlab.com/wyssmann/tf-scm` and is connected to Terraform Cloud — there is **no manual `terraform plan` or `terraform apply`**. Changes are pushed to a branch and merged.

> **Hard rule — never create projects with `glab`.** Do not use `glab repo create`, the GitLab API, the UI, or any other imperative path to create, rename, or change a repository. The only supported route is a `repos_*.tf` change in `tf-scm`. This also applies to verification: confirm the result from the Terraform Cloud run, not by creating or mutating anything with the CLI.

## Repository defaults

- **Topics / labels:** choose a small set of appropriate, relevant repository topics (or project labels) for the repo. Do not invent unrelated tags or leave a new repo without discoverability metadata.
- **Primary repository:** GitLab is always the primary. GitHub is the mirror.
- **GitHub mirrors:** a mirror must live under the GitHub `wyssmann` organization for Wyssmann projects — set `github = { org = "wyssmann" }`. Never use `primary_repo = true` unless the user explicitly makes GitHub the primary.
- **Access:** ask for the ACL preset (`public-build`, `public-minimal`, `private-build`, …) before writing the entry.

## Workflow

When asked to "create a repo", "modify repo settings", "add a branch rule", or similar:

1. **Edit the appropriate `repos_*.tf` file** in `tf-scm` to add or modify the repo resource. Use the GitLab Terraform provider (`gitlab` from the Registry) — invoke `skills/terraform-platform-engineer/SKILL.md` for HCL standards.
2. **Commit to the current branch** — by default, commit changes directly to the branch you're on. Do not create a new branch or worktree unless explicitly asked.
3. **Push** — Terraform Cloud applies the change on merge to main.
4. **Never `terraform import` or `terraform apply` manually** unless explicitly asked. If a resource exists in GitLab but not in Terraform, surface the drift and ask.

### Explicit Request: Worktree + MR

When the user explicitly asks for a worktree, MR, or PR:

1. **Create a worktree** in `tf-scm`.
2. **Edit the appropriate `repos_*.tf` file** as above.
3. **Commit and push** the branch.
4. **Create a MR** using `glab mr create`:
   - Always assign papanito as reviewer.
   - Add adequate labels.
   - Set a descriptive title matching the commit message format.

## Repository Creation Interview (mandatory)

Before creating a repo, ask the user:

- **Personal or group?** Personal repos use the `papanito` prefix; group repos go under a named GitLab group. Ask which.
- **ACL configuration?** Different repos need different access levels (e.g. public, internal, private, shared with specific groups). Ask which ACL to apply.
- **Mirror to GitHub?** Ask if the repo should be mirrored to GitHub. If yes, add `github = { org = "wyssmann" }` (GitLab remains primary) so the mirror is created in the GitHub `wyssmann` organization.
