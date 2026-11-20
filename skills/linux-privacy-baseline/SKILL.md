---
name: linux-privacy-baseline
description: Build a practical privacy baseline on Linux — threat model first, LUKS/KDE Vault encryption, GPG key hygiene, pass password storage, metadata scrubbing, VPN/Tor use, and verification. Use when protecting personal data at rest, hardening a laptop, setting up encrypted storage or a password manager, or advising on anonymity tools without overpromising.
---

# Linux Privacy Baseline

## WHEN TO USE

- A laptop or workstation holds documents, keys, or credentials that must survive theft.
- Setting up encrypted storage, a password manager, or GPG keys.
- Preparing to publish files and needing metadata removed.
- Choosing between VPN, Tor, and Tails for a stated threat model.

## PRE-FLIGHT: threat model

Write down, in one paragraph:

1. **What** must stay private (documents, identity, location, metadata, credentials)?
2. **From whom** (opportunistic thief, employer, ISP, platform, targeted adversary)?
3. **What happens if it fails**, and what inconvenience is acceptable?

Tools do not substitute for the model. A VPN hides traffic from the local network, not from the VPN provider or the destination; Tails protects a session, not a careless action. State limits explicitly.

## PROCEDURE

### 1. Encrypt data at rest

Full-disk (LUKS2):

```sh
sudo cryptsetup luksFormat --type luks2 /dev/nvme0n1p3
sudo cryptsetup open /dev/nvme0n1p3 cryptroot
sudo mkfs.ext4 /dev/mapper/cryptroot
sudo cryptsetup luksDump /dev/nvme0n1p3
```

- Prefer a strong passphrase over a short one with many iterations.
- Keep a tested recovery path: recovery key stored separately, or a documented reinstall decision.
- TPM/auto-unlock trades theft protection for convenience; decide deliberately.
- Suspend-to-disk and hibernation can write keys to swap; encrypt swap too.

Folder-level (KDE Vaults / gocryptfs):

```sh
# KDE Plasma: System Settings → Security → KDE Vaults → Create
# CLI equivalent with gocryptfs:
gocryptfs -init ~/vault-cipher
mkdir -p ~/vault
gocryptfs ~/vault-cipher ~/vault
fusermount -u ~/vault
```

Back up ciphertext **and** the key material separately. Losing the key means losing the data; losing the backup means losing both.

### 2. Store secrets in `pass`

```sh
sudo apt install pass
gpg --quick-generate-key "alice <alice@example.org>" rsa4096 encr 2y
pass init "alice@example.org"
pass insert mail/example
pass generate web/example 24
pass ls
pass show -c mail/example      # clipboard, clears after 45s by default
```

`pass` stores each entry as a GPG-encrypted file under `~/.password-store`, so the security of the store equals the security of the GPG key. Git history is optional (`pass git init`), but never push it to a public remote.

### 3. GPG key hygiene

- Prefer one offline primary key with signing/encryption subkeys, or a hardware token (`gpg --card-status`).
- Set an expiry; renew deliberately.
- Keep the primary private key offline; export only what a given host needs.
- Generate and store a revocation certificate before you need it.
- Never paste a private key into a chat, ticket, or shared host.
- Verify imports by fingerprint, not by display name.

```sh
gpg --list-secret-keys --keyid-format=long
gpg --fingerprint
gpg --export-secret-subkeys > subkeys.asc   # handle offline, then remove
gpg --gen-revoke <key-id> > revocation.asc
```

### 4. Remove metadata before publishing

```sh
exiftool file.pdf
exiftool -all= -overwrite_original file.pdf
mat2 document.docx            # writes a cleaned copy
pdfinfo file.pdf
```

Check images, PDFs, office documents, and archives for author names, GPS coordinates, device serials, comments, and revision history. Screenshots can leak window titles and notification content.

### 5. Network privacy

- WireGuard/OpenVPN for untrusted networks; verify the tunnel is up before trusting it:
  ```sh
  wg show
  ip route get 1.1.1.1
  curl -s https://ifconfig.me
  ```
- Encrypted DNS (DoT/DoH) or a trusted resolver; check with `resolvectl status`.
- Tor Browser for anonymity against the destination; do not mix identities in one session.
- Tails for a amnesic environment; boot from trusted media and do not expect it to protect against compromised hardware or a linked real identity.
- Disable telemetry and per-app network access where the desktop supports it.

### 6. Separate identities and containers

Use distinct browser profiles/containers per identity, Flatpak or `bubblewrap` for untrusted apps, and a separate user account for high-risk activity. Privacy is weakened more often by correlation between identities than by a single broken cipher.

## VERIFY

```sh
lsblk -f | grep -i luks
sudo cryptsetup status cryptroot
gpg --list-secret-keys
pass ls
exiftool file.pdf | grep -Ei 'author|gps|creator'
resolvectl status | grep -Ei 'dns server|dns over tls'
wg show
```

## GUARDRAILS

- Do not claim anonymity a tool cannot provide.
- Do not store a recovery key next to the encrypted disk.
- Do not use `shred` on SSDs or journaling/COW filesystems as a privacy erase (see `linux-drive-sanitization`).
- Do not reuse one GPG key or password-store passphrase across unrelated identities.
- Do not publish a "cleaned" file without inspecting it after scrubbing.

## SOURCES

- <https://linuxsecurity.com/howtos/strengthen-my-privacy/linux-pass>
- <https://linuxsecurity.com/howtos/strengthen-my-privacy/gpg-key-security>
- <https://linuxsecurity.com/howtos/strengthen-my-privacy/how-to-lock-away-sensitive-information-on-linux-with-kde-vaults>
- <https://linuxsecurity.com/howtos/strengthen-my-privacy/tails-linux-privacy-anonymity>
- <https://linuxsecurity.com/howtos/strengthen-my-privacy/connect-via-openvpn-on-ubuntu>
