---
name: linux-log-ir
description: Plan Linux logging and run the first hour of incident response — persistent and off-host journals, retention, clock checks, evidence preservation, and cross-source timeline correlation. Use when investigating a suspected compromise, responding to a live server, or designing logging that can answer who/what/when after a reboot.
---

# Linux Logging and Incident Response

## WHEN TO USE

- A host is suspected compromised and you need to preserve evidence before rebooting.
- Logs must survive reboot, rotation, and host compromise.
- An alert in one source (network, auth, web) needs a timeline across sources.
- Designing retention for audit or investigation requirements.

## PRE-FLIGHT

1. **Do not reboot, power off, or wipe.** Volatile evidence disappears first.
2. Verify clocks are synchronized across hosts; a skewed clock breaks correlation.
3. Confirm which sources exist and whether rotation already removed the relevant window.
4. Determine whether the host can be isolated without causing more harm than the incident.
5. Identify the system owner, business purpose, and whether the host is production.

## PROCEDURE

### 1. Make logs survivable (before an incident)

```sh
# Persistent journal: /var/log/journal instead of /run/log/journal
sudo mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=persistent\nSystemMaxUse=4G\n' | sudo tee /etc/systemd/journald.conf.d/99-persistent.conf
sudo systemctl restart systemd-journald
journalctl --list-boots
```

- Forward selected records to an off-host collector over an encrypted, authenticated channel.
- Give the collector its own access control: a compromised source host must not be able to erase remote records.
- Write retention as owner, destination, access rule, and deletion date per source. Work backward from how late a problem may be discovered.
- Test a restore/retrieval of an older record; an untested archive is a hope, not a control.
- Never log passwords, tokens, or unnecessary personal data.

### 2. Preserve volatile evidence (first 30 minutes)

Run read-only collection and save output off-host:

```sh
date -u; uptime; who; w; last -a | head -50; lastb -a | head -50
ps auxf
pstree -p
ss -plant
lsof -i -P -n
sudo ss -tanp state established
mount
sudo ls -la /proc/<pid>/cwd /proc/<pid>/exe /proc/<pid>/fd 2>/dev/null
```

Capture, if policy allows: process memory, disk image, `/proc/*/environ`, shell history files, `/tmp` and `/dev/shm` contents. Hash and encrypt evidence; record who collected what and when.

### 3. Build the timeline

```sh
journalctl --since "2 hours ago" --no-pager
journalctl -u ssh --since "24 hours ago"
journalctl _COMM=sudo --since "24 hours ago"
journalctl -u <service> --since "24 hours ago"

last -a
lastb -a
sudo ausearch -m USER_LOGIN,USER_AUTH,EXECVE -ts recent
sudo aureport --auth --summary
```

Look for sequences rather than single events:

- Failed SSH attempts → a success from a new source → `sudo` → new account or key.
- `useradd`/`usermod`/`passwd` near a cron or systemd unit creation.
- A web process spawning a shell, then an outbound connection.
- Log gaps or rotation right before the suspicious activity.

### 4. Correlate across sources

Join on host, time (UTC), account, process, and network tuple:

- Auth: `/var/log/auth.log`, `journalctl -u ssh`, audit `USER_AUTH`.
- Privilege: `sudo` journal, `/etc/sudoers` changes, audit `EXECVE`.
- Persistence: cron/systemd changes (see `linux-persistence-detection`).
- Execution: audit `EXECVE`, process accounting, EDR.
- Network: firewall drops, DNS queries, proxy, NetFlow, `ss` snapshots.
- Application: web access/error logs, database audit logs.

For a small team, a spreadsheet or notebook with one row per event and a source column is enough; the structure matters more than the SIEM.

### 5. Decide containment and recovery

- Isolate the host at the network layer only after remote logs are secured.
- Preserve the original disk if the host will be rebuilt.
- Rotate credentials and keys that were present on the host.
- Fix the entry vector, not just the visible payload.
- Re-image when trust in the host cannot be restored; document the decision.

## VERIFY

- `journalctl --list-boots` shows records across a reboot.
- The collector holds a copy the source host cannot delete.
- The timeline has UTC timestamps and cites a source for every claim.
- Evidence hashes match between collection and storage.
- The containment action is recorded with time and operator.

## GUARDRAILS

- Never reboot first and investigate later.
- Never edit or truncate logs to "clean up" before collection.
- Never trust a single log source; the first symptom is rarely the entry point.
- Never claim compromise from one anomaly; require converging evidence.
- Never store evidence unencrypted on the compromised host.

## SOURCES

- <https://linuxsecurity.com/howtos/secure-my-network/linux-log-management-incident-response>
- <https://linuxsecurity.com/howtos/secure-my-network/linux-log-correlation>
- <https://linuxsecurity.com/howtos/secure-my-network/respond-compromised-linux-server>
- <https://linuxsecurity.com/howtos/secure-my-network/linux-security-audit-logs>
- <https://linuxsecurity.com/howtos/harden-my-filesystem/linux-log-analysis-investigate-log-manipulation>
