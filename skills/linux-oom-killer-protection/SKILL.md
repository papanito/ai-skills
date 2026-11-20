---
name: linux-oom-killer-protection
description: Diagnose and prevent Linux out-of-memory kills — read oom_score and memory.events, protect sshd and critical services with OOMScoreAdjust/MemoryMin, cap workloads with MemoryHigh/MemoryMax, and tune systemd-oomd PSI policies, zram/swap, and overcommit. Use when services die with "Killed process", the host freezes under memory pressure, or a workload must fail without taking the box down.
---

# Linux OOM Killer Protection

The kernel OOM killer ends a process when memory cannot be reclaimed. It is a safety valve, not a tuning target: the goal is to make the *right* process die (or none), not to disable it.

## WHEN TO USE

- `journalctl -k` shows `Out of memory: Killed process ...` or a service exits with signal 9.
- SSH becomes unresponsive while a build, backup, database, or container grows.
- A container or user session consumes the host instead of being contained.
- `systemd-oomd` is killing user slices, or needs to be enabled and scoped.
- Sizing `MemoryMax`/`MemoryHigh`, swap, or zram for a workload.

## PRE-FLIGHT

1. Confirm it was an OOM kill, not the service's own supervisor or a crash:
   ```sh
   journalctl -k -b | grep -iE 'out of memory|killed process|oom_reaper'
   journalctl -u <service> -b --no-pager | tail -n 50
   dmesg -T | grep -iE 'oom|killed process'
   ```
2. Record total memory, swap, and current pressure before changing limits:
   ```sh
   free -h
   cat /proc/pressure/memory
   systemd-cgtop -m --iterations=1
   ```
3. Identify the victim and the growth source (leak, cache, concurrency, container limit).
4. Do not disable the OOM killer or set `vm.overcommit_memory=2` as a first move; both convert a bounded kill into a hang or a failed allocation storm.

## PROCEDURE

### 1. Understand who gets killed

The kernel scores each task roughly by its resident memory share plus `oom_score_adj` (`-1000..1000`). Higher score means a more likely victim.

```sh
# Score and adjustment for a process
cat /proc/<pid>/oom_score /proc/<pid>/oom_score_adj

# Largest consumers with their scores
ps -eo pid,user,comm,rss,oom_score,oom_score_adj --sort=-rss | head -n 20

# Runtime adjustment (negative = protect)
sudo choom -p <pid> -n -500
choom -p <pid>
```

`oom_score_adj=-1000` makes a process effectively unkillable by the OOM killer. If that process is the leak, the host may hang instead of recovering. Always pair strong protection with a memory cap.

### 2. Protect the services that must survive

Protect only what is needed to administer or recover the host — typically SSH, not every application.

```sh
# Unit names differ: ssh.service (Debian/Ubuntu) vs sshd.service (RHEL/Fedora)
systemctl cat ssh.service 2>/dev/null || systemctl cat sshd.service
```

Drop-in:

```ini
# /etc/systemd/system/ssh.service.d/oom.conf
[Service]
OOMScoreAdjust=-1000
MemoryMin=64M
```

```sh
sudo systemctl daemon-reload
systemctl show ssh.service -p OOMScoreAdjust -p MemoryMin
systemctl restart ssh.service    # keep a second session open
```

- `MemoryMin=` reserves memory for the cgroup under pressure (cgroup v2).
- `MemoryLow=` is a softer protection; `MemoryHigh=` throttles before the hard limit.
- For a critical daemon, `OOMPolicy=stop` can stop the whole unit cleanly instead of losing one process; the default is `kill` for most services.
- Avoid protecting databases or application workers by default; an unkillable leaking database is worse than a restart.

### 3. Contain workloads with cgroup v2 limits

Put the limit on the workload, not on the host. This turns a host-wide OOM into a scoped failure.

```ini
# Example: a build or batch service
[Service]
MemoryAccounting=yes
MemoryHigh=2G          # throttle/reclaim pressure first
MemoryMax=3G           # hard ceiling; OOM kills inside this cgroup
MemorySwapMax=512M
```

Apply and inspect:

```sh
sudo systemctl daemon-reload
sudo systemctl restart <service>

systemctl show <service> -p MemoryCurrent -p MemoryHigh -p MemoryMax -p MemorySwapMax
cat /sys/fs/cgroup/system.slice/<service>/memory.events
cat /sys/fs/cgroup/system.slice/<service>/memory.pressure
```

`memory.events` counts `high`, `max`, and `oom_kill`; a rising `oom_kill` means the cap is too low or the workload leaks.

For a one-off test without touching a unit:

```sh
sudo systemd-run --scope -p MemoryMax=512M -p MemoryHigh=384M \
  bash -c 'stress-ng --vm 1 --vm-bytes 1G --timeout 30s'
```

The allocation should fail or be killed inside the scope; the host stays responsive.

### 4. Use `systemd-oomd` for pressure-based action

`systemd-oomd` watches PSI and cgroup memory pressure, then kills the largest process in a monitored cgroup. It complements, not replaces, per-unit limits.

```sh
systemctl status systemd-oomd
oomctl
cat /etc/systemd/oomd.conf
```

Global settings (`/etc/systemd/oomd.conf`):

```ini
[OOM]
SwapUsedLimit=90%
DefaultMemoryPressureDurationSec=20s
```

Enable killing for a slice — commonly user sessions, not system services:

```ini
# /etc/systemd/system/user.slice.d/oomd.conf
[Slice]
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=50%
ManagedOOMSwap=kill
```

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now systemd-oomd
oomctl
journalctl -u systemd-oomd -b --no-pager
```

Do not mark `system.slice` or `-.slice` for aggressive killing without understanding which services live there; a broad policy can kill a database or SSH.

### 5. Reduce the chance of pressure

- Fix the leak or cap concurrency; limits only decide who pays.
- Add swap or zram for bursty workloads, not as a substitute for sizing:
  ```sh
  swapon --show
  zramctl
  ```
- Lower `vm.swappiness` only with a measured reason; it changes reclaim behavior, not capacity.
- Review `vm.overcommit_memory` and `vm.overcommit_ratio` only when the workload genuinely needs overcommit semantics; document the sizing.
- Keep `vm.panic_on_oom=0` so the kernel kills a task instead of panicking the host.
- For containers, set the runtime/container memory limit as well; a container without a limit is a host-wide workload.

## VERIFY

```sh
# No new kills after the change
journalctl -k --since "1 hour ago" | grep -iE 'killed process|out of memory'

# Protection actually applied
systemctl show ssh.service -p OOMScoreAdjust -p MemoryMin
systemctl show <service> -p MemoryHigh -p MemoryMax -p MemoryCurrent

# Scoped failures, not host failures
cat /sys/fs/cgroup/system.slice/<service>/memory.events
oomctl
systemd-cgtop -m --iterations=1

# Host still responsive under the same workload
cat /proc/pressure/memory
```

Success means the workload either stays within its cap, fails inside its own cgroup, or is throttled early — while SSH and recovery tooling remain usable.

## GUARDRAILS

- Do not disable the OOM killer (`vm.panic_on_oom=1`, `oom_kill_disable`) to stop messages.
- Do not set `OOMScoreAdjust=-1000` broadly; an unkillable leak can hang the host.
- Do not protect an application you are willing to restart; protect access and recovery paths.
- Do not set `MemoryMax` below measured peak without load-testing the service.
- Do not confuse `systemd-oomd` (userspace, PSI-based) with the kernel OOM killer (allocation failure).
- Do not tune swap or overcommit before identifying the growth source.

## SOURCES

- `man systemd.exec` (`OOMScoreAdjust`, `MemoryMin`, `MemoryLow`, `MemoryHigh`, `MemoryMax`, `OOMPolicy`)
- `man oomd.conf`, `man systemd-oomd.service`, `man oomctl`
- `man choom`, `man proc_pid_oom_score_adj`
- Kernel documentation: `Documentation/admin-guide/mm/concepts.rst` (OOM killer, overcommit)
