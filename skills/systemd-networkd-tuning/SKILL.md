---
name: systemd-networkd-tuning
description: Diagnose and fix slow Linux boots with systemd-analyze, wait-online delays, optional fstab mounts, masked units, and unit dependency/ordering mistakes — plus persistent systemd-networkd, NIC and sysctl tuning. Use when a server takes too long to boot, SSH is late after a reboot, a mount or wait-online job times out, or network throughput and packet drops need tuning.
---

# systemd Boot & Network Performance Tuning

Measure first, change one thing, then re-measure. Most "slow boot" reports come from one waiting unit on the critical chain, not from many services being slow.

## WHEN TO USE

- A reboot leaves SSH or an application unavailable for tens of seconds.
- `systemd-analyze blame` shows a large unit, or `critical-chain` shows a long wait.
- `systemd-networkd-wait-online` / `NetworkManager-wait-online` blocks `network-online.target`.
- An optional disk or NFS share delays boot or drops the host into emergency mode.
- A service has a dependency or ordering mistake (`Wants` vs `Requires`, `After` vs `Before`).
- NIC ring buffers, offloads, queues, or TCP sysctls need persistent tuning.

## PRE-FLIGHT

1. Record a baseline before changing anything:
   ```sh
   systemd-analyze time
   systemd-analyze blame | head -n 20
   systemd-analyze critical-chain
   ```
2. Have console or out-of-band access. A bad `fstab` or masked network unit can make an SSH-only host unreachable.
3. Work one change at a time, during a maintenance window, and keep the previous file or drop-in for rollback.
4. Do **not** mask `systemd-*`, storage, networking, or SSH units to win a few seconds. Verify owners and dependents first.
5. Paths differ by distribution (`/lib/...` vs `/usr/lib/...`). Read the real unit instead of hardcoding a binary path.

## 1. Measure the boot and find the real blocker

```sh
# Total kernel + initrd + userspace, and when the default target was reached
systemd-analyze time

# Units by activation time (suspects, not proof)
systemd-analyze blame | head -n 20

# The longest ordered chain that actually delayed the target
systemd-analyze critical-chain

# Focus on one target or unit
systemd-analyze critical-chain network-online.target
systemd-analyze critical-chain nginx.service

# Visual timeline for a report or comparison
systemd-analyze plot > /tmp/boot.svg
```

Reading the output:

- `blame` sorts by activation duration, but units run in parallel; a slow unit may not delay the target.
- `critical-chain` shows the ordered sequence that reached the target. The `@` value is when the unit became active; `+` is its own duration. Investigate the unit whose duration sits on this chain.
- Compare the same host before/after, not across different hardware.

## 2. Fix `systemd-networkd-wait-online` delays

Default behavior waits for all managed interfaces to reach the required online state, up to the timeout. An unplugged secondary NIC or a missing DHCP reply can therefore hold `network-online.target` for a minute or more.

```sh
systemctl status systemd-networkd-wait-online.service
systemctl cat systemd-networkd-wait-online.service
ip -br link
```

Do not disable the wait service blindly if Nginx, a VPN, or a clustered service genuinely requires `network-online.target`.

### Option A: wait for the interface that matters

```sh
sudo systemctl edit systemd-networkd-wait-online.service
```

Drop-in content:

```ini
[Service]
ExecStart=
ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --interface=enp1s0 --timeout=20
```

- The empty `ExecStart=` clears the packaged command; the second line replaces it.
- Use the exact binary path from `systemctl cat`, not the example.
- Confirm your systemd version supports `--interface=` (`systemd-networkd-wait-online --help`).
- `--any` is an alternative when any single interface being online is sufficient.
- Apply with `sudo systemctl daemon-reload` and verify after the next boot:
  ```sh
  systemd-analyze critical-chain network-online.target
  ```

### Option B: exclude interfaces that should not block boot

In the interface's `.network` file:

```ini
[Match]
Name=eth1

[Link]
RequiredForOnline=no
```

### Option C: stop waiting for unused address families

```ini
[Network]
DHCP=ipv4
LinkLocalAddressing=no
IPv6AcceptRA=no
```

Only do this when IPv6 really is unused; it removes a legitimate readiness signal.

### NetworkManager hosts (RHEL/Rocky/Alma, many desktops)

`NetworkManager-wait-online.service` usually waits because a profile never completes (DHCP timeout, missing Wi-Fi, unplugged bridge port). Inspect the profile and fix the cause before masking the unit:

```sh
nmcli -t -f NAME,DEVICE connection show --active
journalctl -u NetworkManager -b --no-pager | tail -n 50
systemctl status NetworkManager-wait-online.service
```

If nothing on the host needs `network-online.target`, disabling the wait unit is defensible; document why.

## 3. Fix slow or optional mounts (`/etc/fstab`)

A missing disk or unreachable NFS server can stall a `.mount` unit and, on some systems, drop boot into emergency mode.

```fstab
# Optional local disk: keep booting if it is absent, cap device wait
UUID=3f1c2a7e-8b4d-4e2a-9c61-5d7f0b9e2a14  /data         ext4  defaults,nofail,x-systemd.device-timeout=10s  0 2

# Network share: mount on first access, mark as network-dependent
192.168.122.250:/srv/backups               /mnt/backups  nfs   defaults,_netdev,x-systemd.automount           0 0
```

- `nofail` lets boot continue when the optional device is absent.
- `x-systemd.device-timeout=10s` caps how long systemd waits for the device to appear; it does not cap the filesystem mount itself.
- `_netdev` marks the mount as network-dependent.
- `x-systemd.automount` defers the mount until the path is accessed.
- A service that reads the share can still trigger the mount and hit network delays; check its dependencies.

Validate before rebooting:

```sh
sudo findmnt --verify
sudo systemctl daemon-reload
systemctl status data.mount
systemctl status mnt-backups.automount
```

If boot already failed: `journalctl -xb` finds the failing `.mount`. Emergency mode may not offer a root shell (Ubuntu locks root), which is exactly why `findmnt --verify` matters on remote hosts.

## 4. Disable or mask units the host does not need

```sh
systemctl list-unit-files --type=service --state=enabled
systemctl list-dependencies --reverse ModemManager.service
```

Safe sequence:

```sh
sudo systemctl stop ModemManager.service
# observe logs and a normal workload cycle
sudo systemctl disable ModemManager.service
# only if nothing may start it, including D-Bus or another unit
sudo systemctl mask ModemManager.service
```

`mask` links the unit to `/dev/null` and is stronger than `disable`; reverse it with `systemctl unmask`. A masked unit that something still needs produces "Unit ... is masked" — investigate the dependent, do not unmask by reflex.

## 5. Fix unit dependencies and ordering

Two different concepts:

- `Wants=` / `Requires=` decide whether another unit is pulled into the transaction. `Wants=` does not make its success mandatory; `Requires=` is stronger but still interacts with ordering and failure settings.
- `After=` / `Before=` only order units that are already in the transaction. `After=network-online.target` does not pull that target in.

Typical over-coupling:

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=Internal API
Wants=postgresql.service
After=network.target postgresql.service

[Service]
User=myapp
ExecStart=/opt/myapp/bin/myapp
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

- A local-socket or local-only app does not need `network-online.target`; use `network.target` at most.
- `Wants=network-online.target` + `After=network-online.target` is appropriate only when the service genuinely cannot start before the network is configured — and it reintroduces the wait-online delay.
- `After=postgresql.service` does not mean PostgreSQL is ready to accept connections. Add application retries or a proper readiness check.
- Use `Wants=` rather than `Requires=` for optional companions unless you intend a hard dependency.

Validate and apply:

```sh
sudo systemd-analyze verify /etc/systemd/system/myapp.service
sudo systemctl daemon-reload
sudo systemctl enable --now myapp.service
systemctl status myapp.service
journalctl -u myapp.service -b --no-pager
```

"Found ordering cycle" means two ordering constraints contradict each other; `systemd-analyze verify` and the boot log name the units involved.

## 6. NIC and link-layer tuning (`.link` files)

Use `/etc/systemd/network/10-<interface>.link` so driver settings survive reboot instead of living in ad-hoc `ethtool` commands. Match by `MACAddress=` or `OriginalName=`.

```ini
# /etc/systemd/network/10-uplink.link
[Match]
MACAddress=aa:bb:cc:dd:ee:ff

[Link]
# Verify hardware maxima with: ethtool -g <interface>
RxBufferSize=4096
TxBufferSize=4096

TCP6SegmentationOffload=true
TCPSegmentationOffload=true
GenericSegmentationOffload=true
GenericReceiveOffload=true

# Disable LRO when forwarding/routing
LargeReceiveOffload=false

ReceiveChecksumOffload=true
TransmitChecksumOffload=true

# Verify supported/max channels with: ethtool -l <interface>
CombinedChannels=8

# Only with end-to-end MTU 9000 support
# MTUBytes=9000
```

`.link` files are applied by `systemd-udevd` when the interface initializes. Option names and availability vary by systemd version — check `man systemd.link` for the installed release before adding a key.

## 7. Network, route, and kernel tuning

`.network` route/window settings:

```ini
# /etc/systemd/network/20-uplink.network
[Match]
Name=eth0

[Link]
RequiredForOnline=yes

[Network]
Address=192.0.2.10/24
DNS=1.1.1.1 9.9.9.9
LLMNR=no
MulticastDNS=no

[Route]
Gateway=192.0.2.1
InitialCongestionWindow=30
InitialAdvertisedReceiveWindow=30
FastOpenNoCookie=yes
```

Kernel side:

```ini
# /etc/sysctl.d/99-network-performance.conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.ipv4.tcp_max_syn_backlog = 8192

net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
```

```sh
sudo sysctl --system
```

Tune against a measured problem (drops, retransmits, high BDP). Raising every buffer on a small VM only increases memory pressure.

## 8. Apply and verify

```sh
# systemd-networkd configuration
sudo networkctl reload
sudo networkctl reconfigure <interface>

# Current link state, ring buffers, offloads
networkctl status <interface>
ethtool -g <interface>
ethtool -k <interface>
ethtool -S <interface> | grep -iE 'drop|err|miss|fifo'

# Routes, qdisc, congestion control
ip route show
tc qdisc show dev <interface>
sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc

# Boot regression check after reboot
systemd-analyze time
systemd-analyze blame | head -n 20
systemd-analyze critical-chain
```

Success means the unit that topped `critical-chain` is gone or bounded, the target is reached earlier, and the host still performs its role.

## GUARDRAILS

- Never disable `systemd-networkd-wait-online` without checking what requires `network-online.target`.
- Never mask networking, storage, `systemd-*`, or SSH units to improve a timing number.
- `nofail` hides a missing required disk; use it only for genuinely optional mounts.
- Do not edit `/etc/fstab` on a remote host without `findmnt --verify` and a recovery path.
- Do not tune sysctls or ring buffers without a baseline and a measured symptom.
- Do not assume the slowest `blame` entry is the boot blocker; confirm it on `critical-chain`.
- Do not apply `.link`/`.network` options your installed systemd does not support.

## SOURCES

- <https://www.tecmint.com/speed-up-systemd-boot-time-in-linux/>
- `man systemd-analyze`, `man systemd.unit`, `man systemd.link`, `man systemd.network`, `man systemd.mount`
