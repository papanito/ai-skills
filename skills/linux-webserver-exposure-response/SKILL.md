---
name: linux-webserver-exposure-response
description: Contain a Linux web server data leak end to end — stop every serving path, preserve evidence, rotate credentials, detect web shells and unexpected process/network behavior, harden MariaDB, and remove exposed content from caches and search indexes. Use after a public backup or export is found, during web-shell triage, or when securing a new web/database host.
---

# Linux Web Server Exposure Response

## WHEN TO USE

- A database export, backup, log archive, or private document is reachable over HTTP.
- Search results or mirrors expose content that has already been removed from the origin.
- A web process spawns shells or makes unexpected outbound connections.
- A new web host with MariaDB/MySQL needs a secure baseline.

## PRE-FLIGHT

- Treat the data as public already. Fixing the server does not undo distribution.
- Do not reboot, power down, or wipe before evidence collection; coordinate imaging and memory capture if the host may be compromised.
- Record every action with time, operator, and reason.
- Involve legal/privacy owners early if personal data is exposed.

## PROCEDURE

### 1. Stop public access at every serving point

Block the route, not just the directory listing:

```sh
# Find what the web tier actually serves
grep -RInE 'root|alias|location|proxy_pass' /etc/nginx /etc/apache2 2>/dev/null
```

Check and close:

- Direct file URLs (disabling directory browsing does **not** protect a known filename).
- Application download/export endpoints and object-storage links.
- Alternate domains/subdomains, HTTP and HTTPS variants, aliases, and symlinks.
- CDN/reverse-proxy caches: purge the object, not only the origin.
- Permissions on the storage path and any public bucket/ACL.

```sh
curl -sS -o /dev/null -w '%{http_code}\n' https://host/backups/customer-export.sql
curl -sSI https://host/backups/customer-export.sql
```

### 2. Preserve evidence, then rotate

- Save relevant logs and configuration privately and encrypted; restrict access to the responders.
- Record what was exposed, from when, to whom (access logs), and the exact URLs.
- Rotate passwords, API tokens, session secrets, and SSH keys that were present on the host.
- Invalidate cached credentials and active sessions where the application supports it.

### 3. Remove from indexes, caches, and mirrors

- Add `X-Robots-Tag: noindex` or a `robots.txt` disallow while removal is in progress.
- Use the search engine's removal/refresh tooling (Google Search Console, Bing Webmaster) for urgent removal; `robots.txt` prevents crawling, not indexing of existing URLs.
- Request purge from caches, archives, and mirrors; verify with a direct request and a `site:` search.
- Keep a removal log: URL, engine/cache, request date, confirmation.

### 4. Hunt for web shells and execution anomalies

Start with access logs, not a file scan:

```sh
grep -E 'POST.*\.(php|jsp|aspx)' /var/log/nginx/access.log | tail -n 50
grep -E 'eval|base64_decode|system\(|passthru|shell_exec' -R /var/www --include='*.php' 2>/dev/null | head
```

Behavioral checks that signatures miss:

```sh
ps auxf                           # web user spawning sh/bash
pstree -p "$(pgrep -x nginx | head -1)"
ss -tnp | grep -E ':(80|443)\b'   # outbound from web tier
sudo lsof -i -P -n | grep -E 'nginx|apache|php-fpm'
find /var/www -type f -newermt '-7 days' -printf '%TY-%Tm-%Td %TH:%TM %p\n'
```

A web worker should not spawn an interactive shell or open arbitrary outbound connections. Correlate three signals before concluding: suspicious request path, unexpected process tree, unexpected outbound connection.

### 5. Secure a MariaDB/MySQL host

```sh
sudo apt install mariadb-server -y
sudo systemctl status mariadb
sudo systemctl enable mariadb
sudo mysql_secure_installation
```

Then:

```ini
# /etc/mysql/mariadb.conf.d/50-server.cnf
bind-address = 127.0.0.1
```

- No anonymous accounts, no remote root, no test database.
- One application account per app, least privilege on its schema only.
- Require TLS for any remote database connection.
- Back up with encryption and store backups outside the web root.

### 6. Verify TLS and exposure

```sh
openssl s_client -connect host:443 -servername host </dev/null 2>/dev/null | openssl x509 -noout -dates -subject
curl -sSI http://host/.git/ | head
curl -sSI http://host/backups/ | head
```

Renew certificates before expiry (ACME/ZeroSSL), redirect HTTP to HTTPS, and remove exposed `.git`, `.env`, editor backups, and directory indexes.

## VERIFY

- Every previously exposed URL returns `403`/`404` from outside, including alternate hostnames and caches.
- Search removal requests are filed and the URLs no longer resolve in results.
- No web process spawns a shell and no unexplained outbound connection remains.
- Credentials that were on the host are rotated.
- The incident record contains what, when, who, and the evidence location.

## GUARDRAILS

- Do not assume `Options -Indexes` protects a file whose URL is known.
- Do not delete the exposed file or shell before recording its path, hash, and timestamps.
- Do not stop at the origin: caches, CDNs, and mirrors keep serving.
- Do not leave a database listening on `0.0.0.0` because "the firewall handles it".
- Do not promise deletion from third-party copies you do not control.

## SOURCES

- <https://linuxsecurity.com/howtos/secure-my-webserver/linux-server-data-leak-response>
- <https://linuxsecurity.com/howtos/secure-my-webserver/web-shell-detection-linux>
- <https://linuxsecurity.com/howtos/secure-my-webserver/web-server-incident-response>
- <https://linuxsecurity.com/howtos/secure-my-webserver/installing-securing-mariadb>
- <https://linuxsecurity.com/howtos/secure-my-webserver/secure-your-linux-server>
