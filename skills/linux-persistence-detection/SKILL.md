---
name: linux-persistence-detection
description: Find and investigate Linux persistence established through systemd units/timers, cron, at jobs, shell profiles, and file-integrity drift — capturing evidence before deleting anything. Use when a process keeps returning after being killed, an unknown service or timer exists, or startup paths and configuration files changed unexpectedly.
---

# Linux Persistence Detection

## WHEN TO USE

- A killed process or removed script comes back after a reboot or a few minutes.
- An unknown service, timer, cron entry, or user-level unit is found.
- A web shell or command-and-control channel is suspected.
- Security-relevant files changed without a change record.

## PRE-FLIGHT (evidence first)

1. **Do not delete, kill, or reboot yet.** The launch mechanism and its metadata are the evidence.
2. Capture for every finding: owning account, exact command/script, schedule, file timestamps, permissions, hashes, and whether the same hash exists on other hosts.
3. Record the host's role and exposure. An unknown unit on a public e-commerce host is not the same as on a lab box.
4. Decide isolation separately from cleanup; preserve remote logs before network isolation if the collector is local.

## PROCEDURE

### 1. Inventory systemd persistence

```sh
systemctl list-unit-files --type=service
systemctl list-unit-files --type=timer
systemctl list-timers --all
systemctl list-units --type=service --state=running

# Inspect the real unit and its drop-ins, not just the name
systemctl cat suspicious.service
systemctl show suspicious.service -p ExecStart -p FragmentPath -p DropInPaths
```

Red flags:

- `ExecStart` pointing at `/tmp`, `/dev/shm`, `/var/tmp`, or a user-writable path.
- A timer firing every few minutes with no operational reason on that host.
- A unit whose name mimics a system component but whose path is non-standard.
- `Restart=always` used to resurrect a payload.
- User-level units: `systemctl --user list-units --all` (check each human account).

Also inspect: `/etc/systemd/system`, `/run/systemd/system`, `/usr/lib/systemd/system` (modified files), `~/.config/systemd/user`, and generator output.

### 2. Inventory cron, at, and scheduled execution

```sh
# Per-user crontabs (including service accounts)
for u in $(cut -d: -f1 /etc/passwd); do echo "== $u"; crontab -l -u "$u" 2>/dev/null; done

cat /etc/crontab
ls -la /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly
atq
ls -la /var/spool/cron /var/spool/cron/crontabs 2>/dev/null
```

Look for: entries owned by service accounts that never schedule work, commands fetched over the network (`curl ... | sh`), encoded payloads, writes into `/tmp` or `/dev/shm`, and entries with mtimes newer than the last approved change.

### 3. Check other autostart paths

```sh
# Shell profiles and rc files
grep -RInE 'curl|wget|base64|/dev/shm|/tmp/' /etc/profile /etc/profile.d /etc/bash.bashrc \
  ~/.bashrc ~/.bash_profile ~/.profile ~/.zshrc 2>/dev/null

# Loader and boot hooks
cat /etc/ld.so.preload 2>/dev/null
ls -la /etc/rc.local /etc/init.d 2>/dev/null
ls -la /etc/udev/rules.d

# SSH forced commands and keys
grep -RIn 'command=' /root/.ssh /home/*/.ssh 2>/dev/null
```

Also review `authorized_keys`, PAM configuration, sudoers, and package-manager hooks (`/etc/apt/apt.conf.d`, `/etc/dnf/plugins`).

### 4. Detect file-integrity drift

Monitor the files that define trust, not the whole filesystem:

- `/etc/ssh/sshd_config`, `/etc/passwd`, `/etc/shadow`, `/etc/group`
- `/etc/sudoers`, `/etc/sudoers.d/`, PAM configuration
- systemd unit files, cron directories, firewall rule files
- kernel module configuration, package-manager configuration
- privileged scripts, system binaries, shared libraries

AIDE workflow:

```sh
sudo aideinit                    # or: aide --init (distro dependent)
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
sudo aide --check
sudo aide --update                # only after verified changes
```

Keep the database, config, and AIDE binary off the monitored host or on read-only media. If an attacker can rewrite the baseline, the comparison proves nothing.

### 5. Investigate before cleanup

```sh
systemctl status suspicious.service
systemctl cat suspicious.service
stat /path/to/payload
sha256sum /path/to/payload
journalctl -u suspicious.service --since "7 days ago"
```

Then correlate: which account created it, from where, and what else that account touched. Removing the unit without understanding the entry vector leaves the attacker a way back in.

## VERIFY

- `systemctl list-timers --all`, `systemctl list-unit-files`, and all crontabs are accounted for.
- Every remaining unit/cron entry has a named owner and purpose.
- The suspicious hash is searched across the fleet; sibling hosts are checked.
- After approved cleanup, a reboot test (on a non-critical clone if possible) confirms nothing returns.

## GUARDRAILS

- Do not kill a process and stop there; the launcher remains.
- Do not `systemctl disable` a unit before copying it and its drop-ins.
- Do not trust unit names or file names as evidence of legitimacy.
- Do not rebuild the AIDE baseline to silence an alert you have not explained.
- Do not clean a production host before capturing volatile evidence.

## SOURCES

- <https://linuxsecurity.com/howtos/harden-my-filesystem/detect-linux-persistence-cron-systemd>
- <https://linuxsecurity.com/howtos/harden-my-filesystem/linux-persistence-incident-response>
- <https://linuxsecurity.com/howtos/secure-my-network/find-remove-malicious-cron-jobs-linux>
- <https://linuxsecurity.com/howtos/harden-my-filesystem/detect-unauthorized-file-changes-linux>
- <https://linuxsecurity.com/howtos/secure-my-webserver/web-shell-detection-linux>
