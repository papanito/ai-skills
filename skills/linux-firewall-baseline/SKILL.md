---
name: linux-firewall-baseline
description: Establish and audit a Linux host firewall baseline with UFW, firewalld, or nftables — default-deny inbound, explicit service allows, egress review, and first-match troubleshooting. Use when exposing a new host, reviewing open ports, investigating unexpected outbound traffic, or debugging rules that appear present but do not apply.
---

# Linux Firewall Baseline

## WHEN TO USE

- A new server or container host needs a documented default-deny posture.
- "The port is open but the rule is there" or traffic disappears with no log line.
- Outbound/egress traffic needs review after an unexplained connection.
- UFW, firewalld, and raw nftables are mixed on one host and the effective policy is unclear.

## PRE-FLIGHT

1. Identify the management path (SSH CIDR, VPN, bastion) **before** changing policy.
2. Have console/out-of-band access. A remote flush can end the session.
3. Establish which backend actually enforces: `systemctl status ufw firewalld nftables` and `nft list ruleset`.
4. Snapshot the current state: `sudo ufw status verbose`, `sudo firewall-cmd --list-all`, `sudo nft list ruleset`.
5. If a change is risky, schedule a rollback: `sudo sh -c 'sleep 300; ufw --force reset' &` is crude; a documented timed revert or console session is better.

## PROCEDURE

### 1. Map what is listening

```sh
ss -tulpen
sudo ss -tulpenp
systemctl list-units --type=service --state=running
```

Decide per socket: public, internal-only, or unnecessary. Unnecessary services should be removed or bound to `127.0.0.1`, not merely firewalled.

### 2. Set the baseline (UFW example)

```sh
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 10.10.10.0/24 to any port 22 proto tcp
sudo ufw allow 80,443/tcp
sudo ufw --force enable
sudo ufw status verbose
sudo ufw status numbered
```

### 3. Equivalent nftables skeleton

```nft
table inet filter {
  chain input {
    type filter hook input priority filter; policy drop;
    iif lo accept
    ct state established,related accept
    ct state invalid drop
    ip protocol icmp accept
    ip6 nexthdr ipv6-icmp accept
    tcp dport 22 ip saddr 10.10.10.0/24 accept
    tcp dport { 80, 443 } accept
  }
  chain forward { type filter hook forward priority filter; policy drop; }
  chain output  { type filter hook output  priority filter; policy accept; }
}
```

Validate and apply:

```sh
sudo nft -c -f /etc/nftables.conf   # syntax check
sudo systemctl enable --now nftables
sudo nft list ruleset
```

Firewalld equivalent:

```sh
sudo firewall-cmd --permanent --set-default-zone=public
sudo firewall-cmd --permanent --zone=public --add-service=https
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="10.10.10.0/24" service name="ssh" accept'
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

### 4. Review egress

Outbound is the neglected half. A compromised process with unrestricted egress needs no clever exfiltration path.

- Allow DNS, NTP, package mirrors, and documented APIs.
- Log or drop unexpected destinations; start with logging rather than a hard drop on production.
- Remember first-match wins: one overly broad `accept` above a `drop` disables the drop.

```sh
sudo nft list chain inet filter output
sudo journalctl -k --since "1 hour ago" | grep -Ei 'drop|reject'
```

### 5. Troubleshoot in this order

1. Is the service enforcing? (`systemctl status`, not just rule listings)
2. What is the default policy? (`ufw status verbose`, `nft list ruleset`, zone target)
3. Which rule matches **first**? Order beats intent.
4. Correct interface/zone/source? (`-i`, `-o`, `--zone`)
5. Do logs show `DROP`/`REJECT` or nothing at all? Nothing usually means upstream filtering or logging disabled.
6. Is IPv6 handled separately?
7. Does Docker/container publishing bypass the host rules? Docker writes its own nat/filter chains; UFW rules do not cover published container ports. Use `DOCKER-USER` or bind published ports to localhost.

## VERIFY

```sh
sudo ufw status verbose       # or firewall-cmd --list-all / nft list ruleset
sudo nft list ruleset | grep -E 'policy|dport'
nc -vz <host> 22              # from an allowed and a denied source
sudo journalctl -k -n 50 | grep -Ei 'drop|reject'
```

Document the intended public ports next to the rules; a baseline without an expected-state list cannot be audited.

## GUARDRAILS

- Never test a remote firewall by flushing all rules without console access.
- Do not open a port globally to fix a localhost-only problem; bind the service to `127.0.0.1`.
- Do not duplicate the same allow in UFW, firewalld, and nftables; pick one owner.
- Do not assume `ufw status` covers container traffic.
- Do not disable the firewall "just to test"; use a temporary rule and logs.

## SOURCES

- <https://linuxsecurity.com/howtos/secure-my-firewall/linux-firewall-basics-with-ufw>
- <https://linuxsecurity.com/howtos/secure-my-firewall/egress-filtering-for-a-healthier-internet-28128>
- <https://linuxsecurity.com/howtos/secure-my-firewall/introduction-to-troubleshooting-linux-firewalls-76066>
- <https://linuxsecurity.com/howtos/secure-my-firewall/linux-firewalls-packet-filtering>
