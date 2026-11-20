---
name: linux-drive-sanitization
description: Sanitize and verify HDDs, SATA SSDs, NVMe drives, and LUKS volumes on Linux before reuse or disposal — NIST SP 800-88 Clear/Purge/Destroy selection, device identification, overwrite, ATA secure erase, NVMe sanitize, crypto erase, and recorded verification. Use when decommissioning hardware, returning leased equipment, or handling failed drives with sensitive data.
---

# Linux Drive Sanitization

## WHEN TO USE

- Servers, workstations, or arrays are being refreshed, sold, returned, or scrapped.
- A drive held SSH keys, TLS certificates, databases, credentials, logs, or customer data.
- A failed drive cannot be wiped and a destruction decision is needed.
- Media will be reused internally and "quick format" is the current plan.

## PRE-FLIGHT (destructive)

1. Classify data sensitivity, media type, and disposition (reuse internally, reuse externally, destroy).
2. Back up anything that must survive. **All data on the target will be lost permanently.**
3. Use an offline maintenance environment where possible.
4. Identify the device by serial and model, not by `sdX`:
   ```sh
   lsblk -o NAME,MODEL,SERIAL,SIZE,ROTA,TRAN,MOUNTPOINTS
   sudo smartctl -i /dev/sdX
   ```
   `ROTA=1` usually means HDD, `0` non-rotational; `TRAN` shows SATA/NVMe/SAS/USB. Device names change across reboots — match the serial to the physical asset immediately before erasure.
5. Ensure the target is not mounted, not swap, and not a member of RAID/LVM:
   ```sh
   findmnt /dev/sdX
   sudo swapoff -a
   sudo vgchange -an <vg>
   sudo mdadm --stop /dev/mdX
   ```

## PROCEDURE

### 1. Choose the sanitization level

NIST SP 800-88 Rev. 2 defines:

- **Clear** — data cannot feasibly be recovered through standard device access (e.g. overwrite user-accessible storage). Does not guarantee remapped or inaccessible areas.
- **Purge** — data cannot feasibly be recovered with advanced laboratory methods; media may be reusable (proper overwrite, secure erase, or correct cryptographic erase).
- **Destroy** — data cannot feasibly be recovered and the media is no longer usable.

Match the level to sensitivity and destination. Internal reuse may need Purge; a failed drive that cannot complete a method may need physical destruction. The commands below are not NIST certifications.

### 2. Spinning HDD — overwrite (Clear)

```sh
# Single pass of zeros; more passes do not reach inaccessible sectors
sudo dd if=/dev/zero of=/dev/sdX bs=4M status=progress conv=fsync

# Alternative: one random pass plus a zero pass
sudo shred -n 1 -z -v /dev/sdX
```

`dd` normally ends with "No space left on device" because `/dev/zero` is infinite. That message alone is **not** proof of completion: check bytes written against the device's user-accessible size and investigate any earlier I/O error.

### 3. SATA SSD — ATA secure erase (Purge)

```sh
sudo hdparm -I /dev/sdX | grep -A6 -i security
sudo hdparm --user-master u --security-set-pass 'temporary-passphrase' /dev/sdX
sudo hdparm --user-master u --security-erase 'temporary-passphrase' /dev/sdX
```

If the drive reports `frozen`, suspend/resume the host or hot-plug the drive to unfreeze it. Enhanced secure erase (`--security-erase-enhanced`) is preferable when supported. Never interrupt the erase.

### 4. NVMe — sanitize or format (Purge)

```sh
sudo nvme id-ctrl /dev/nvmeX | grep -E 'SANICAP|MN|SN'
sudo nvme sanitize /dev/nvmeX -a 2        # block erase; -a 4 = crypto erase if supported
sudo nvme sanitize-log /dev/nvmeX         # poll progress
sudo nvme format /dev/nvmeX --ses=1       # alternative: user-data erase
```

Use crypto erase (`-a 4`) only when the controller supports it and the key material is actually destroyed. Check `SANICAP` for supported actions.

### 5. LUKS volumes — crypto erase

```sh
sudo cryptsetup luksDump /dev/sdX
sudo cryptsetup luksErase /dev/sdX        # destroys keyslots; requires confirmation
```

After `luksErase`, the header still exists but no key can decrypt the data. Overwrite the header as well if policy requires, and confirm no keyfile, header backup, or passphrase survives elsewhere. Destroy all header backups; otherwise the erase is reversible.

### 6. Failed drives

If a drive cannot complete Clear or Purge, do not return it to service and do not resell it. Follow the organization's physical destruction procedure and record the asset serial, failure, and destruction method.

## VERIFY AND RECORD

```sh
# Spot-check that no readable filesystem signature remains
sudo blkid /dev/sdX
sudo dd if=/dev/sdX bs=1M count=64 status=none | hexdump -C | head

# NVMe erase progress
sudo nvme sanitize-log /dev/nvmeX
```

Verification of every sector is impractical; combine the method's guarantees with a read-back spot check. Record per asset: serial, model, media type, data classification, method, tool/version, operator, start/end time, result, and disposition. Keep the record with the decommissioning paperwork.

## GUARDRAILS

- Never run these commands against `/dev/sda` by habit; verify serial and size first.
- Never sanitize a mounted filesystem, active swap, or a RAID/LVM member in use.
- Never treat `quick format`, `mkfs`, or deleting the partition table as sanitization.
- Never run `shred` on SSDs, flash, or copy-on-write filesystems expecting physical overwrite; use the device's secure erase/sanitize.
- Never interrupt a secure erase or sanitize operation.
- Never release a drive whose sanitization result is unknown.

## SOURCES

- <https://linuxsecurity.com/howtos/harden-my-filesystem/sanitizing-drives-linux-before-disposal>
- NIST SP 800-88 Rev. 2 (media sanitization)
