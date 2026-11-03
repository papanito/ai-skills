
# GitLab Instructions

## Issue Work

Before acting on an issue, inspect the repository origin with
`git remote get-url origin` to identify the host; use `glab` for GitLab and
`gh` for GitHub. Never assume the host. For GitLab issues, log time spent (for example,
`glab issue note <id> --message "/spend 30m"` or an equivalent time-tracking
command).

## CI Pipeline

- **GitLab CI `script` items must be strings.** When writing `.gitlab-ci.yml` jobs, every `script:` entry MUST be a plain string (or a nested array of strings, max 10 levels deep) — never a YAML mapping/dict. A single quoted item like `- echo "key: value"` parses as a dict unless the whole item is quoted (`- 'echo "key: value"'`). After editing, validate with `python3 -c "import yaml; [print(n, [type(i).__name__ for i in (j.get('script') or []) if not isinstance(i, str)]) for n, j in yaml.safe_load(open('.gitlab-ci.yml')).items() if isinstance(j, dict)]"` — expect no output.

## Merge Request Conventions

- **Add appropriate labels when creating an MR** (and when its scope changes). Map the change onto the target project's existing label set — list it with `glab api "projects/<owner>%2F<repo>/labels?per_page=100"`. Typical mapping: `type::feature` / `type::bug` / `type::maintenance` as the primary label, plus a specific one (`feature::addition`, `feature::enhancement`, `bug::functional`, `maintenance::pipelines`, `maintenance::release`, …) where one fits. Never invent labels; if nothing fits, leave labels off and say so rather than creating new ones unasked.

## Release Push

The `/do-release-gitlab` workflow may push its branch and tag as specified by
its instructions. Do not push automatically outside that documented workflow
unless the user explicitly asks.
