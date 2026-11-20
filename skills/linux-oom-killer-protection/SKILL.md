---
name: systemd-networkd-tuning
description: Optimize Linux server boot speed and network throughput using systemd-networkd (.link and .network unit files), systemd-networkd-wait-online tuning, NIC ring buffer/offload configuration, and sysctl kernel parameters. Use when diagnosing slow network boot waits, RX/TX packet drops, or high-latency network performance on systemd-based Linux systems.
---

# systemd-networkd Performance & Boot Tuning

Optimize Linux server boot times and network throughput persistently via `systemd-networkd` unit files (`/etc/systemd/network/`) and kernel `sysctl` parameters rather than ad-hoc `ethtool` or `ip` commands.

---

## 1. Diagnose Boot Delays & Network Bottlenecks

Before modifying unit files, identify whether delays occur during boot (`systemd-networkd-wait-online`) or at runtime (NIC ring buffers, offloads, or kernel queues).

```bash
# Check boot time consumed by network services
systemd-analyze blame | grep -E 'networkd|wait-online'

# Inspect interface state, link speed, and active unit files
networkctl status <interface>

# Check NIC ring buffer limits and current allocations
ethtool -g <interface>

# Check hardware offload states (TSO, GSO, GRO, LRO, checksums)
ethtool -k <interface>

# Check NIC statistics for RX/TX drops or FIFO errors
ethtool -S <interface> | grep -iE 'drop|err|miss|fifo'

# Check interface qdisc and packet drops
ip -s link show <interface>
```

---

## 2. Speed Up Server Boot (`systemd-networkd-wait-online`)

By default, `systemd-networkd-wait-online.service` blocks boot until **all** configured interfaces reach an online state (up to a 2-minute timeout), delaying multi-NIC servers or systems with unused ports.

### Option A: Wait Only for Any Single Interface (`--any`)
Create a systemd drop-in override so boot proceeds as soon as the primary management/uplink interface is up:

```bash
mkdir -p /etc/systemd/system/systemd-networkd-wait-online.service.d
cat <<'EOF' > /etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf
[Service]
ExecStart=
ExecStart=/lib/systemd/systemd-networkd-wait-online --any --timeout=15
EOF
systemctl daemon-reload
```
*(Note: Verify binary path via `which systemd-networkd-wait-online` or `systemctl cat systemd-networkd-wait-online.service`—on RHEL/Fedora/Arch it is `/usr/lib/systemd/systemd-networkd-wait-online`.)*

### Option B: Ignore Secondary/Unused Interfaces in `.network` Files
For interfaces that should not block boot (e.g., isolated storage/heartbeat NICs or disconnected ports), add `RequiredForOnline=no` under `[Link]`:

```ini
[Match]
Name=eth1

[Link]
RequiredForOnline=no
```

### Option C: Skip Unused IP Address Families
Prevent DHCPv6 or IPv6 Router Advertisement delays on IPv4-only networks (or vice versa):

```ini
[Network]
DHCP=ipv4
LinkLocalAddressing=no
IPv6AcceptRA=no
```

---

## 3. Hardware & Link-Layer Tuning (`.link` Files)

Use `/etc/systemd/network/10-<interface>.link` to persistently configure NIC driver settings, ring buffers, and hardware offloads at boot (replacing manual `ethtool` scripts). Match by `MACAddress=` or `OriginalName=` so naming remains deterministic.

```ini
# /etc/systemd/network/10-uplink.link
[Match]
MACAddress=aa:bb:cc:dd:ee:ff

[Link]
# Increase RX/TX ring buffers to hardware maximums (verify with `ethtool -g`)
RxBufferSize=4096
TxBufferSize=4096

# Enable hardware segmentation & receive offloads
TCP6SegmentationOffload=true
TCPSegmentationOffload=true
GenericSegmentationOffload=true
GenericReceiveOffload=true

# Disable LargeReceiveOffload if forwarding/routing packets (prevents packet corruption/reordering)
LargeReceiveOffload=false

# Enable RX/TX checksum offloading
ReceiveChecksumOffload=true
TransmitChecksumOffload=true

# Multi-queue RSS/channel scaling (match CPU core count up to NIC max from `ethtool -l`)
CombinedChannels=8

# Jumbo frames (only enable if end-to-end switches/VLANs support MTU 9000)
# MTUBytes=9000
```

> **Note:** Changes to `.link` files are applied by `systemd-udevd` when the interface is initialized. Apply without rebooting by triggering udev or reloading the NIC driver, or reboot during a maintenance window.

---

## 4. Network & Route-Layer Tuning (`.network` Files)

Configure `/etc/systemd/network/20-<interface>.network` to optimize congestion windows, routing behavior, and ARP/neighbor handling.

```ini
# /etc/systemd/network/20-uplink.network
[Match]
Name=eth0

[Link]
RequiredForOnline=yes
# MTUBytes=9000

[Network]
Address=192.0.2.10/24
DNS=1.1.1.1 9.9.9.9
# Disable LLMNR and mDNS on servers to reduce multicast chatter and attack surface
LLMNR=no
MulticastDNS=no

[Route]
Gateway=192.0.2.1
# Increase initial TCP congestion/receive windows (in MSS segments) for high-BDP WAN links
InitialCongestionWindow=30
InitialAdvertisedReceiveWindow=30
# Enable Fast Open without cookies on trusted private links if supported
FastOpenNoCookie=yes
```

---

## 5. Kernel TCP/IP & Queue Discipline Tuning (`sysctl`)

Pair `systemd-networkd` settings with kernel socket buffer and congestion control tuning in `/etc/sysctl.d/99-network-performance.conf`:

```ini
# /etc/sysctl.d/99-network-performance.conf

# Use Fair Queue (fq) + BBR congestion control to eliminate bufferbloat and maximize throughput
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Increase socket receive/send buffer maximums (16 MB for 10GbE+)
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Increase NIC backlog and SYN queue capacity for traffic bursts
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.ipv4.tcp_max_syn_backlog = 8192

# Enable TCP window scaling and timestamps; disable slow-start after idle
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_slow_start_after_idle = 0

# Reuse TIME_WAIT sockets safely for outbound connections
net.ipv4.tcp_tw_reuse = 1
```

Apply sysctl changes immediately:

```bash
sysctl --system
```

---

## 6. Reload & Verify Configuration

1. **Validate unit syntax and reload `systemd-networkd`:**
   ```bash
      networkctl reload
         networkctl reconfigure <interface>
            ```
            2. **Verify active link parameters and ring buffers:**
               ```bash
                  networkctl status <interface>
                     ethtool -g <interface>
                        ethtool -k <interface>
                           ```
                           3. **Verify routes, congestion windows, and qdisc:**
                              ```bash
                                 ip route show
                                    tc qdisc show dev <interface>
                                       sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc
                                          ```
                                          4. **Verify boot timing on next reboot:**
                                             ```bash
                                                systemd-analyze blame | grep -E 'networkd|wait-online'
                                                   ```