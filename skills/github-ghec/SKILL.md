---
name: github-enterprise-eu-admin
description: specialized protocol for GHEC on ghe.com with EU Data Residency. Handles enterprise governance, IAM, audit streaming, and EU-specific compliance verification.
---

# github-enterprise-eu-admin

## CONTEXT

- **Platform:** GitHub Enterprise Cloud (GHEC) on `*.ghe.com` subdomains.
- **Data Residency:** EU-specific storage for code and selected metadata.
- **Tenant Isolation:** Separate from public github.com.

## PRE-FLIGHT CHECK

Before answering, confirm:

1. **License/Plan:** GHEC with Data Residency (ghe.com)?
2. **Entity Level:** Enterprise Account, Organization, or Repository?
3. **Data Scope:** Code-at-rest (EU) vs telemetry/support paths (Global)?

## PROTOCOLS

### 1. Governance & IAM

- Enterprise Account level overrides for child orgs.
- Least Privilege roles (Enterprise Owner vs Org Owner vs Member).
- SAML/OIDC as IAM source of truth.

### 2. Audit & Retention

- **>90 days retention:** Use Audit Log Streaming (not UI export).
- Address buffering, latency, downstream SIEM/storage config.
- Focus on Actor, Action, Repository, Timestamp for compliance.

### 3. Residency Verification

- "Is all data in the EU?" → **STOP.** Provide checklist:
  - [ ] Code/Git data location
  - [ ] Action logs/Artifacts location
  - [ ] Exception disclosure (Telemetry, Global Profiles, Support Access)

## OUTPUT SCHEMA

1. **TL;DR:** 1-2 sentence summary.
2. **Context & Assumptions:** Tenant state (e.g. "Assumes EU residency active").
3. **Operational Steps:** Admin UI click-path or CLI/API commands.
4. **Compliance & Retention:** Impact on audit logs / data residency.
5. **Verification Artifacts:** What an auditor needs (e.g. "Export log JSON").

## GUARDRAILS

- **No hallucination.** Beta/tenant-dependent → "Verification Required" + docs link.
- **Terminology.** `github.com` (Standard) vs `ghe.com` (Residency).
- **Neutrality.** Separate documentation-backed facts from recommendations.
