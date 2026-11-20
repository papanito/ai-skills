---
name: linux-attack-surface-reduction
description: Shrink a Linux host's attack surface by auditing listening sockets, running and enabled services, and installed packages, then removing or sandboxing what is not needed. Use when hardening a new server, investigating an unexpected open port, or trimming a bloated production image.
---

# Linux Attack Surface Reduction

## WHEN TO USE

- A host has more services, ports, or packages than its role requires.
- A new server build needs a defensible "what runs here and why" inventory.
- An unexpected listener or daemon appears in a scan.
- A service must stay but should be contained (sandboxing, localhost binding, non-root user).

## PRE-FLIGHT

1. Establish the host's role and owner. "Internal app server" is a usable scope; "all Linux" is not.
2. Collect evidence before changing anything:
   ```sh
   ss -tulpen
   systemctl list-units --type=service --state=running
   systemctl list-unit-files --state=enabled
   dpkg -l    # or: rpm -qa
   ```
3. For every candidate, identify the owning team, dependent clients, and the rollback path.
4. Change one service at a time and watch logs through a full traffic cycle.

## PROCEDURE

### 1. Build the inventory

```sh
# Listening sockets with process and user
sudo ss -tulpen

# Running services and enabled-at-boot units
systemctl list-units --type=service --state=running
systemctl list-unit-files --state=enabled

# Packages that pull in daemons or setuid helpers
dpkg -l | awk '/^ii/ {print $2}'    # Debian/Ubuntu
rpm -qa                              # RHEL/Fedora

# What is exposed beyond localhost
sudo ss -tulpen | awk 'NR==1 || $5 !~ /127\.0\.0\.1|\[::1\]/'
```

Classify each listener: public by design, internal-only, or unnecessary. "Unknown" is a finding to resolve, not a category to keep.

### 2. Remove what is not needed

Safe sequence for a suspected-unused service:

```sh
sudo systemctl stop foo.service
sudo journalctl -u foo.service --since "10 min ago"
# observe for a full traffic cycle (hours/days for batch systems)
sudo systemctl disable foo.service
```

- Do not `disable` and walk away: a stopped-but-enabled unit can return on reboot; a disabled-but-running unit keeps serving until restart.
- Mask (`systemctl mask`) only when you are sure nothing may start it, including socket activation and dependencies.
- Remove packages with the package manager (`apt purge`, `dnf remove`), not by deleting files.
- Check socket-activated and timer-driven units, not just running processes: `systemctl list-sockets`, `systemctl list-timers --all`.

### 3. Reduce exposure without removing function

```sh
# Bind to loopback in the app/unit, e.g.
# ListenAddress 127.0.0.1
# -H 127.0.0.1:8080
```

- Put a reverse proxy in front of an app that must stay reachable.
- Bind databases and caches to `127.0.0.1` or a private interface; never `0.0.0.0` by default.
- Use a dedicated unprivileged user and `AmbientCapabilities=` instead of running as root.
- Drop capabilities the service does not use: `NoNewPrivileges=yes`, `PrivateTmp=yes`, `ProtectSystem=strict`, `ProtectHome=yes`, `RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX`.

### 4. Measure and contain the remainder

```sh
systemd-analyze security nginx.service
systemd-analyze security --offline=yes ./unit.service
```

Start with the highest-exposure units. Sandboxing is iterative: add one directive, restart, confirm the service still works, then add the next. Read the score as a guide, not a compliance certificate.

## VERIFY

```sh
sudo ss -tulpen                      # expected listeners only
systemctl --failed
systemctl list-sockets
systemctl list-timers --all
journalctl -u <changed-unit> --since "1 hour ago"
systemd-analyze security <unit>
```

Confirm the host still performs its role (health check, synthetic request, backup run) before declaring the reduction complete.

## GUARDRAILS

- Never uninstall a package or stop a service without an identified owner and rollback.
- Never expose an internal datastore to "make debugging easier".
- Do not judge risk by port number alone; a listener on localhost can still be reachable through a proxy.
- Do not chase a perfect `systemd-analyze security` score at the cost of a working service.
- Do not forget containers: published ports bypass host firewall expectations.

## SOURCES

- <https://linuxsecurity.com/howtos/harden-my-filesystem/reduce-linux-attack-surface>
- <https://linuxsecurity.com/howtos/secure-my-network/audit-open-ports-linux-server>
- <https://linuxsecurity.com/howtos/learn-tips-and-tricks/security-configuration-management-linux>
