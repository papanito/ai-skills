---
name: nixos-expert-protocol
description: specialized protocol for NixOS system architecture and debugging. Handles declarative configurations, Flakes, Nix store management, and module-based service orchestration.
---

# nixos-expert-protocol

## CONTEXT

- **Model:** Declarative, immutable, reproducible.
- **Store:** `/nix/store` with generation-based rollbacks.
- **Tooling:** `nixos-rebuild`, `nix build`, `nix shell`, `nix develop`.
- **Exclusions:** Strictly ignore Flatpak and Snap.

## PRE-FLIGHT CHECK

Before proposing a Nix expression, identify:

1. **Flake Status:** `flake.nix` or `configuration.nix`?
2. **Channel:** Stable vs `nixos-unstable` vs pinned inputs.
3. **Environment:** NixOS vs `nix-darwin` vs standalone Nix.
4. **Error Type:** Evaluation, Build, or Runtime?
5. **Closure drift:** for a runtime crash, name the profile that owns the failing binary *and* the profile that owns the session environment. Equal versions are not equal store paths.

## PROTOCOLS

1. **Declarative override:** Never suggest manual `/etc` edits or imperative `systemctl`. Map traditional Linux actions to NixOS options. Prefer `lib.mkIf`, `lib.mkMerge`, `lib.mkDefault`.
2. **Flake-native:** If Flakes enabled, provide `outputs`/`inputs` logic. Use `specialArgs` for cross-module config.
3. **Debugging:** Request `nixos-rebuild` stderr, `nix log`, or `journalctl -u`. Provide the config diff to fix state.
4. **Closure identity:** when a fix depends on a tool behaving, assert its *store path* (`nix eval --raw .#…outPath`), not its version — two builds of the same version are not interchangeable.
5. **`buildEnv` collisions:** `two given paths contain a conflicting subpath` → `lib.lowPrio` the losing package. The builder honours `meta.priority` (no rebuild, no `ignoreCollisions`); `pkgs.lowPrio` was removed in 26.05.
6. **Core dumps:** never `systemd.coredump.enable = false` — the kernel falls back to `core_pattern=core` and every crash drops an uncapped `core.<pid>` in the crashing process's CWD. Keep coredump on with `Storage=external` plus size caps, and triage with `coredumpctl list` / `coredumpctl info <pid>` (stack + mapped modules). Never clean by filename alone — `core*` also matches schema files; verify with `file`.

## CLOSURE DRIFT

Standalone home-manager tracking a different nixpkgs than the system profile is the usual
cause: `PATH` yields the user-profile binary, while the session exports
`GI_TYPELIB_PATH`/`LD_LIBRARY_PATH` from the system closure, so two copies of the same
library end up in one process. Identical version strings hide it completely.

- **Symptoms:** `cannot register existing type 'GOutputStream'`,
  `g_once_init_leave_pointer: assertion 'result != 0'`,
  `Gjs:ERROR … assertion failed: (gtype != G_TYPE_INVALID)`, `Bail out!`, SIGABRT with a
  core dump; reproducible from a bare `import Gio` — no application code involved.
- **Diagnose:** which binary vs which environment?
  ```sh
  readlink -f "$(command -v gjs)"                                   # what PATH gives
  nix-store -q --references "$(dirname "$(readlink -f "$(command -v gnome-shell)")")/.." | grep gjs
  tr '\0' '\n' < "/proc/$(pgrep -x gnome-shell)/environ" | grep GI_TYPELIB_PATH
  ```
- **Prove it:** run the same test file twice — with the session's `GI_TYPELIB_PATH` and
  with `env -u GI_TYPELIB_PATH`. Only the drifted binary aborts.
- **Fix:** pin the standalone home-manager's `nixpkgs` to the exact rev in
  `/etc/nixos/flake.lock` and its `home-manager` input to the same release branch; then
  `nix eval --raw .#homeConfigurations.<user>.pkgs.gjs.outPath` must equal the gjs store
  path referenced by the shell closure.
- **Never** set `GI_TYPELIB_PATH` in `profiles/*` to paper over it: it only reaches
  `/etc/set-environment` (TTY/SSH), never the GNOME user session, and the profile dir it
  usually points at has no `Gio-2.0.typelib`.

## OUTPUT SCHEMA

1. **Approach:** NixOS-native method.
2. **Implementation:** Minimal idiomatic Nix snippet.
3. **Execution:** Apply commands (`nixos-rebuild switch`) + verify.
4. **Safety:** Side effects on Nix store or generation size.

## GUARDRAILS

- **Zero filler.** User is a Linux expert — don't explain standard concepts.
- **No inventions.** Undocumented option → suggest `man configuration.nix` or `nixos-option`.
- **Standardization.** Use `pkgs.<package>` and proper module structure.
