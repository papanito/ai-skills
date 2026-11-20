---
name: linux-ssh-hardening
description: Harden OpenSSH beyond key-only authentication on Linux — effective-config audits with sshd -T, root/account/source restrictions, key inventory and authorized_keys abuse checks, brute-force evidence, and safe reloads. Use when reviewing sshd_config, locking down admin access, or investigating suspicious SSH logins and forgotten keys.
---

# Linux SSH Hardening

## WHEN TO USE

- Password authentication is already disabled and the next layer of hardening is needed.
- An internet-facing host needs account, source, and rate limits reviewed.
- `authorized_keys` sprawl, former-contractor access, or lateral movement is suspected.
- Repeated failed logins, `fail2ban` tuning, or "who logged in?" questions.

## PRE-FLIGHT (do not skip)

1. Keep the current session open and open a **second** session for testing.
2. Confirm a named account has working `sudo` and that console/out-of-band access exists.
3. Validate before every reload: `sudo sshd -t`. A bad config plus a restart can lock you out.
4. Know that `sshd -T` shows the *effective* config. `Include /etc/ssh/sshd_config.d/*.conf` is usually first, and **the first value wins** — editing the bottom of `sshd_config` may change nothing.
5. `reload` applies config; `restart` drops sessions. Prefer `reload` unless the unit is wedged.

## PROCEDURE

### 1. Read the effective configuration

```sh
sudo sshd -T | grep -Ei 'permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|allowusers|allowgroups|maxauthtries|logingracetime|maxstartups|allowagentforwarding|allowtcpforwarding|x11forwarding|permittunnel|permituserenvironment'
```

Compare that output — not the file — with the intended posture.

### 2. Apply the baseline

In the file that actually wins (`/etc/ssh/sshd_config.d/00-hardening.conf` is a safe place):

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
MaxStartups 10:30:60
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PermitTunnel no
PermitUserEnvironment no
```

Adjust `AllowTcpForwarding` if tunnels are a documented requirement. Then:

```sh
sudo sshd -t && sudo systemctl reload sshd
sudo sshd -T | grep -Ei 'permitrootlogin|allowusers|allowgroups|maxauthtries'
```

### 3. Restrict who and where

```text
AllowGroups ssh-admins
```

- One group is easier to maintain than per-host `AllowUsers` lists; both work.
- Restrict source networks at the firewall or with a `Match Address` block. A compromised key is useless against an unreachable service.
- Verify `AllowGroups` members with `getent group ssh-admins` before reloading.

Firewalld example:

```sh
sudo firewall-cmd --permanent \
  --add-rich-rule='rule family="ipv4" source address="10.10.10.0/24" service name="ssh" accept'
sudo firewall-cmd --reload
```

### 4. Inventory and police keys

```sh
# Every authorized_keys file on the host, excluding pseudo-filesystems
sudo find / -xdev -type f -name authorized_keys 2>/dev/null

# Fingerprints, comments, and options for each file
while read -r f; do echo "== $f"; ssh-keygen -lf "$f"; done < <(sudo find / -xdev -type f -name authorized_keys 2>/dev/null)
```

For each key record: account, home, fingerprint, owner, purpose, date added. Investigate keys that are:

- Unowned, tied to a former employee, a retired host, or a finished project.
- Duplicated across unrelated accounts or hosts (shared key = shared blast radius).
- Stored in service/automation accounts that never need interactive login.
- Added recently without a change record.

Monitor changes rather than relying on quarterly review:

```sh
# auditd watch on the directory, not just the file
sudo auditctl -w /home/admin/.ssh -p wa -k ssh_keys
sudo ausearch -k ssh_keys -ts recent
```

Also check private keys left on hosts (`find / -xdev \( -name 'id_*' -o -name '*.pem' \)`) and shell history for `ssh-copy-id`.

### 5. Reduce pre-auth abuse

```sh
sudo fail2ban-client status sshd        # if fail2ban is deployed
sudo journalctl -u ssh --since "24 hours ago" | grep -E 'Failed|Invalid|Accepted'
sudo lastb -a | head
```

Set `MaxAuthTries 3`, `LoginGraceTime 30`, `MaxStartups 10:30:60`, and use `fail2ban` for noisy exposure. These generate visible log evidence; they do not replace key hygiene.

## VERIFY

- `sudo sshd -T` shows every intended value.
- A fresh login works from an allowed account/source; a disallowed account is refused.
- `last -a` and `journalctl -u ssh` show the test login.
- `sshd -t` exits 0 and the unit is `active (running)`.

## GUARDRAILS

- Never disable root login until sudo and console access are proven.
- Never change `Port` and call it hardening; it only reduces noise.
- Never use `PermitRootLogin prohibit-password` when `no` is possible.
- Do not delete a suspicious key before recording its fingerprint and file metadata.
- Do not hand-edit a drop-in that a config-management tool owns; change the source of truth.

## SOURCES

- <https://linuxsecurity.com/howtos/secure-my-network/harden-ssh-on-linux>
- <https://linuxsecurity.com/howtos/secure-my-network/unauthorized-ssh-keys-lateral-movement>
- <https://linuxsecurity.com/howtos/secure-my-network/install-configure-fail2ban>
- <https://linuxsecurity.com/howtos/secure-my-network/understand-failed-authentication-patterns-linux-logs>
