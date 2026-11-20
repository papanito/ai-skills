---
name: linux-supply-chain-safety
description: Reduce software supply-chain risk on Linux — verify Git clients and clone without recursive submodules, inspect submodule sources, check signatures and checksums, avoid curl-pipe-shell installs, and treat environment variables as an injection boundary. Use when cloning untrusted repositories, adding dependencies or CI actions, installing downloaded binaries, or reviewing how code and secrets enter a host.
---

# Linux Supply-Chain Safety

## WHEN TO USE

- Cloning a repository you do not control, especially with submodules.
- Installing software from a release tarball, installer script, or unpinned CI action.
- A build agent, container image, or CI runner executes third-party code.
- Reviewing environment-variable handling across sudo, SSH, and systemd.

## PRE-FLIGHT

1. Identify what executes during the operation, not just what is downloaded.
2. Prefer a pinned version plus a verified checksum over "latest".
3. Assume a repository can be crafted to attack the client, CI, or developer workstation.
4. Keep secrets out of the clone path, build logs, and environment dumps.

## PROCEDURE

### 1. Patch the Git client before cloning

Recursive clones of crafted repositories were a code-execution path fixed in Git 2.56.1 and the maintenance releases 2.55.1, 2.54.1, 2.53.1, 2.52.1, 2.51.3, and 2.50.2 (CVE-2026-111760). The attack did not require opening project files or running setup scripts.

```sh
git --version
command -v -a git          # multiple copies often exist
/usr/bin/git --version     # embedded/app-bundled copies may lag
```

Distribution packages may backport the fix while keeping an older version string, so check the vendor advisory and changelog rather than the number alone. Confirm CI images and vendored Git copies too.

### 2. Clone without loading submodules

```sh
git clone REPOSITORY_URL project
cd project
cat .gitmodules 2>/dev/null
```

- Do **not** use `--recurse-submodules` on an unknown project.
- Inspect each submodule URL, owner, and commit before fetching:
  ```sh
  git config -f .gitmodules --get-regexp '^submodule\..*\.(path|url)$'
  git submodule status
  ```
- Fetch a submodule only after its source is verified:
  ```sh
  git submodule update --init path/to/submodule
  ```
- Be cautious with hooks and filters from an untrusted repository. Review `.git/hooks`, `.gitattributes` filter drivers, and `core.hooksPath` before running builds.
- Prefer a commit or signed tag you verified over a moving branch.

### 3. Verify provenance and integrity

```sh
git verify-tag v1.2.3
git log --show-signature -1
git rev-parse HEAD

sha256sum -c SHA256SUMS
gpg --verify release.tar.gz.sig release.tar.gz
```

- Compare the signing key fingerprint with an independent channel (project site, maintainer docs), not with a key served by the same compromised host.
- Pin container images by digest, not by a floating tag.
- Pin CI actions to a commit SHA, not a tag that can move.
- Record the exact version/digest you approved.

### 4. Avoid executing installers blind

```sh
# Prefer this
curl -fLO https://example.org/tool-1.2.3.tar.gz
sha256sum tool-1.2.3.tar.gz
gpg --verify tool-1.2.3.tar.gz.sig

# Not this
curl -fsSL https://example.org/install.sh | sudo sh
```

If an installer script is unavoidable, download it, read it, verify its origin, and run the smallest necessary step without `sudo` where possible. Never pipe a network response into a privileged shell.

### 5. Treat environment variables as an injection boundary

A variable is input from whoever can set it. Do not cross a trust boundary with attacker-controlled values.

- SSH: inspect `AcceptEnv` on the server and `SendEnv` on the client; restricted/forced-command accounts should not accept locale or loader variables.
- `sudo`: keep `env_reset`; do not add broad `env_keep` for `LD_*`, `PATH`, `LANGUAGE`, or `BASH_ENV`.
- systemd: `Environment=`/`EnvironmentFile=` are read as root; restrict file permissions and never source shell syntax from them.
- Privileged scripts: reset `PATH`, avoid `eval`, quote expansions, and ignore inherited `IFS`/`CDPATH`.
- Never pass secrets on the command line (visible in `ps`) or log full environments; `/proc/<pid>/environ` is readable to the owner and root.

```sh
sudo sshd -T | grep -i acceptenv
sudo grep -RInE 'env_keep|env_reset' /etc/sudoers /etc/sudoers.d/
sshd -T | grep -i permituserenvironment
```

### 6. Document an approved baseline

- Choose guidance for the distribution/release (e.g. CIS Benchmark Level 1 as a starting document), then record deviations with owner, reason, and residual risk.
- Do not build a new server by copying an old one whose ports and exceptions nobody remembers.
- Keep dependency updates and image rebuilds on a schedule; an unpatched pinned version is still a vulnerability.

## VERIFY

```sh
git --version
git config -f .gitmodules --get-regexp '^submodule\..*\.(path|url)$'
git submodule status
sha256sum -c SHA256SUMS
gpg --verify <sig> <file>
sudo sshd -T | grep -iE 'acceptenv|permituserenvironment'
```

## GUARDRAILS

- Never `--recurse-submodules` an untrusted repository.
- Never `curl | sudo sh`.
- Never verify a signature with a key fetched from the same unverified source.
- Never pin to a tag when a commit/digest is available.
- Never put secrets in `Environment=`, shell history, URLs, or build logs.

## SOURCES

- <https://linuxsecurity.com/howtos/learn-tips-and-tricks/how-to-clone-a-git-repository-safely>
- <https://linuxsecurity.com/howtos/learn-tips-and-tricks/set-environment-variable-linux-safely>
- <https://linuxsecurity.com/howtos/learn-tips-and-tricks/security-configuration-management-linux>
- <https://linuxsecurity.com/howtos/learn-tips-and-tricks/defense-in-depth-cybersecurity>
