---
name: linux-access-control-baseline
description: Apply least privilege on Linux by auditing accounts, sudo rules, ownership, POSIX ACLs, setuid binaries, and SELinux labels — then making reversible changes without breaking services. Use when reviewing who can log in or escalate, cleaning up permission creep, or fixing SELinux denials without disabling enforcement.
---

# Linux Access Control Baseline

## WHEN TO USE

- A server has accumulated shared accounts, dormant logins, or broad sudo rules.
- Files are world-writable, owned by the wrong account, or need group/ACL access.
- A service fails despite "correct" permissions and SELinux is suspected.
- Preparing least-privilege changes before an audit or migration.

## PRE-FLIGHT

1. Map dependencies: which service accounts do which applications use?
2. Back up `sudoers`, PAM, and relevant config: `sudo cp -a /etc/sudoers /etc/sudoers.bak` (and `sudoers.d`).
3. Keep a root/console session open and know the rollback command.
4. Test on staging when the change affects authentication or a running application.
5. Use `visudo` for sudoers — it syntax-checks and refuses to save a broken file.

## PROCEDURE

### 1. Inventory privilege

```sh
# Human accounts and shells
getent passwd | awk -F: '$3 >= 1000 {print $1, $3, $7}'
getent passwd | awk -F: '$7 !~ /(nologin|false)$/ {print $1, $7}'

# Who can sudo, and to what
sudo -l -U alice
getent group sudo wheel
sudo grep -RInE '^[[:space:]]*[^#].*ALL' /etc/sudoers /etc/sudoers.d/ 2>/dev/null

# Files that grant or leak privilege
sudo find / -xdev -type f -perm -4000 -ls 2>/dev/null
sudo find / -xdev -type f -perm -2000 -ls 2>/dev/null
sudo find / -xdev -type f -perm -0002 -ls 2>/dev/null   # world-writable
```

Review: dormant accounts, shared logins, service accounts with shells, blanket `ALL=(ALL) ALL`, old contractor access, and setuid binaries you cannot justify.

### 2. Reduce account and sudo scope

```sh
# Lock a dormant account without deleting audit history
sudo usermod -L alice
sudo chage -l alice
sudo chage -E 2026-12-31 alice     # optional expiry

# Service accounts: no interactive shell
sudo usermod -s /usr/sbin/nologin svc-deploy
```

Prefer specific commands over blanket sudo, in `/etc/sudoers.d/`:

```text
%deploy ALL=(root) /usr/bin/systemctl restart nginx
%deploy ALL=(root) /usr/bin/systemctl status nginx
```

Check the whole tree, not just the file:

```sh
sudo visudo -c
sudo -l -U alice
```

Avoid `NOPASSWD` unless automation requires it; if it does, keep the command list narrow and the account non-interactive.

### 3. Fix ownership and permissions deliberately

```sh
namei -l /srv/app/config.yml      # show every path component
stat -c '%U:%G %a %n' /srv/app/config.yml
sudo chown root:app /srv/app/config.yml
sudo chmod 640 /srv/app/config.yml
```

Rules of thumb:

- Directories need execute to traverse; files do not.
- `750` directories and `640` files for service data; `600` for secrets.
- Never `chmod 777`; use group ownership or ACLs instead.
- Set a restrictive `umask` (`027` for services, `077` for private data) in the unit or shell profile.
- Sticky bit (`1777`) is correct for shared world-writable directories such as `/tmp`, not for application data.

POSIX ACLs when one extra identity needs access:

```sh
sudo setfacl -m u:deploy:rX /srv/app
sudo setfacl -d -m u:deploy:rX /srv/app      # default ACL for new files
getfacl /srv/app
```

Remove an ACL with `setfacl -x u:deploy /srv/app`. Document why an ACL exists; they are invisible to `ls -l` except for the `+`.

### 4. Troubleshoot SELinux without disabling it

```sh
getenforce
sestatus
sudo ausearch -m AVC -ts recent
sudo sealert -a /var/log/audit/audit.log    # if setroubleshoot is installed
ls -Z /srv/app
ps -eZ | grep nginx
```

- `Enforcing` blocks and logs; `Permissive` logs without blocking; `Disabled` removes the control and the evidence.
- Use permissive mode only to confirm SELinux is the cause, then return to enforcing.
- Fix labels first: `sudo restorecon -Rv /srv/app`.
- For a permanent non-standard path: `sudo semanage fcontext -a -t httpd_sys_content_t '/srv/app(/.*)?'` then `restorecon -Rv /srv/app`.
- `chcon` is temporary and is undone by relabeling; prefer `semanage fcontext`.
- A denial can also mean the service is doing something it should not. Do not write a policy to permit genuinely unsafe behavior without review.

## VERIFY

- `sudo -l -U <user>` shows only intended commands.
- `visudo -c` passes and a test `sudo` works for each admin.
- `namei -l`, `stat`, and `getfacl` match the intended matrix.
- The service starts and writes as expected, with no new AVC denials: `sudo ausearch -m AVC -ts recent`.
- Dormant accounts cannot authenticate (`su - alice` or an SSH test).

## GUARDRAILS

- Do not delete accounts or home directories before preserving audit evidence.
- Do not `chmod -R 777` to make a service work.
- Do not leave SELinux in permissive mode as a permanent fix.
- Do not put broad `ALL` rules in `sudoers.d` because a narrow rule was inconvenient.
- Do not rely on file mode alone when ACLs or SELinux labels also apply.

## SOURCES

- <https://linuxsecurity.com/howtos/harden-my-filesystem/apply-least-privilege-linux>
- <https://linuxsecurity.com/howtos/harden-my-filesystem/ownership-access-control>
- <https://linuxsecurity.com/howtos/harden-my-filesystem/troubleshoot-selinux-without-disabling>
- <https://linuxsecurity.com/howtos/learn-tips-and-tricks/techopt-chmod-calculator-spotlight>
