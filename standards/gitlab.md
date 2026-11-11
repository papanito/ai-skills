
# GitLab Instructions

## Issue Work

Before acting on an issue, inspect the repository origin with
`git remote get-url origin` to identify the host; use `glab` for GitLab and
`gh` for GitHub. Never assume the host. For GitLab issues, log time spent (for example,
`glab issue note <id> --message "/spend 30m"` or an equivalent time-tracking
command).

## CI Pipeline

- **Run Linux jobs on the homelab runner.** Every Linux job in `.gitlab-ci.yml` MUST set `tags: [homelab]`. Never leave a Linux job untagged and never tag one with a GitLab.com SaaS tag (`saas-linux-*`) unless the user explicitly asks for a hosted runner. GitLab only matches a job to a runner carrying every one of its tags, so a job without the tag waits for a hosted runner while the homelab machine idles. Jobs that need a platform the homelab runners do not provide keep their hosted tag (for example `saas-windows-medium-amd64`, `saas-macos-medium-m1`); state that exception in a comment. Before relying on the tag, confirm the `homelab` runner is assigned and online for the project (`glab api "projects/<owner>%2F<repo>/runners"`), otherwise every job stays pending with "no runners online".
- **GitLab CI `script` items must be strings.** When writing `.gitlab-ci.yml` jobs, every `script:` entry MUST be a plain string (or a nested array of strings, max 10 levels deep) — never a YAML mapping/dict. A single quoted item like `- echo "key: value"` parses as a dict unless the whole item is quoted (`- 'echo "key: value"'`). After editing, validate with `python3 -c "import yaml; [print(n, [type(i).__name__ for i in (j.get('script') or []) if not isinstance(i, str)]) for n, j in yaml.safe_load(open('.gitlab-ci.yml')).items() if isinstance(j, dict)]"` — expect no output.

## Merge Request Conventions

- **Create an MR only when the user explicitly asks for one, and never merge it.** Opening an MR is never how a task is "finished" — the pushed branch is. Merging, approving, and auto-merge belong to the user alone: never run `glab mr merge`, never trigger the merge through the API or the UI, even when asked. Hand over the MR URL and its pipeline/review state instead.
- **Add appropriate labels when creating an MR** (and when its scope changes). Map the change onto the target project's existing label set — list it with `glab api "projects/<owner>%2F<repo>/labels?per_page=100"`. Typical mapping: `type::feature` / `type::bug` / `type::maintenance` as the primary label, plus a specific one (`feature::addition`, `feature::enhancement`, `bug::functional`, `maintenance::pipelines`, `maintenance::release`, …) where one fits. Never invent labels; if nothing fits, leave labels off and say so rather than creating new ones unasked.

## Release Push

The `/do-release-gitlab` workflow is **not** a standing authorization to push.
Ask the user before pushing the release branch and tag, and treat the answer as
covering that single push only. Otherwise, do not push automatically — here or
anywhere else — unless the user asks for that specific push; tags, force-pushes,
and remote branch deletions included.
