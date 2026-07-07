# GitLab Repository Management via Terraform

## Overview

Repositories are managed with Terraform, not the GitLab UI or CLI. The Terraform project lives at `https://gitlab.com/wyssmann/tf-scm` and is connected to Terraform Cloud — there is **no manual `terraform plan` or `terraform apply`**. Changes are pushed to a branch and merged.

## Workflow

When asked to "create a repo", "modify repo settings", "add a branch rule", or similar:

1. **Create a worktree** in `tf-scm`.
2. **Edit the appropriate `repos_*.tf` file** to add or modify the repo resource. Use the GitLab Terraform provider (`gitlab` from the Registry) — invoke `skills/terraform-platform-engineer/SKILL.md` for HCL standards.
3. **Commit and push** the branch — Terraform Cloud applies the change on merge.
4. **Create a MR** using gitlab cli
   - always assign papanito as reviewer
   - add adequate labels
   - assign papanito as reviwer
5. **Never `terraform import` or `terraform apply` manually** unless explicitly asked. If a resource exists in GitLab but not in Terraform, surface the drift and ask.

## Repository Creation Interview (mandatory)

Before creating a repo, ask the user:

- **Personal or group?** Personal repos use the `papanito` prefix; group repos go under a named GitLab group. Ask which.
- **ACL configuration?** Different repos need different access levels (e.g. public, internal, private, shared with specific groups). Ask which ACL to apply.
- **Mirror to GitHub?** Ask if the repo should be mirrored to GitHub. If yes, add the mirror resource to the Terraform config.
