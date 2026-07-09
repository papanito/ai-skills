---
name: gnome-shell-extension-local-dev
description: "Build, symlink-install, enable, debug, and package a GNOME Shell extension locally on GNOME 46–50 (Wayland-safe). Use when creating or iterating on any gnome-shell extension."
---

# GNOME Shell Extension Local Dev (GNOME 46–50)

## When to use
Creating, iterating on, or packaging a GNOME Shell extension. Covers project structure, import paths, gettext, threading, live install/enable, debugging, and CI packaging.

## Project structure (GNOME 50 verified)
```
<uuid>@<domain>/
  metadata.json          # uuid, name, shell-version[], version (int), version-name (str), settings-schema, gettext-domain
  extension.js           # import { Extension, gettext as _ } from 'resource:///org/gnome/shell/extensions/extension.js'
  prefs.js               # import { ExtensionPreferences } from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js'
  codeburn.js (etc)      # helper modules — receive gettext as a parameter, never import it
  stylesheet.css
  schemas/<schema>.gschema.xml
  install.sh             # symlink/enable/reload script (pure bash)
  Makefile               # install/link/uninstall/schemas targets
  .gitlab-ci.yml         # pack/validate/upload/release pipeline
```
UUID format: `name@domain.tld`. The extension dir name MUST equal the uuid.

## Import paths (critical — getting either wrong silently breaks loading)
- **extension.js**: `import { Extension, gettext as _ } from 'resource:///org/gnome/shell/extensions/extension.js'` (lowercase `shell`)
- **prefs.js**: `import { ExtensionPreferences } from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js'` (capital `Shell/Extensions`, different path `js/extensions/prefs.js`)
- **helper modules**: do NOT import gettext. Receive it as a constructor/method parameter from extension.js.

## gettext (GNOME 45+ ESM)
- `gettext` from `extension.js` can ONLY be called while an extension's code is executing
- Calling `_()` at module-import time (top-level const, helper module import) throws `Error: gettext can only be called from extensions` → extension fails to load (state INITIALIZED, stuck in error, indicator never appears)
- **Correct pattern**: in `extension.js`, pass `_` (the module-level import) into helper constructors: `new MyIndicator(settings, _)`. Helpers store as `this._` and call `this._('...')` only inside method bodies (render/init time)
- In `prefs.js`, use `this.gettext.bind(this)` as a local `_` inside `fillPreferencesWindow`
- Add `gettext-domain` to `metadata.json`
- Debug: `gdbus call --session --dest org.gnome.Shell.Extensions --object-path /org/gnome/Shell/Extensions --method org.gnome.Shell.Extensions.GetExtensionErrors <uuid>`

## Threading (GJS)
- `GLib.Thread.try_new()` is NOT introspectable in GJS — throws immediately
- Use `GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => { ... return GLib.SOURCE_REMOVE; })` for synchronous spawns that take ~1s
- The shell tolerates a brief block at idle priority

## GObject signals
- Declare in `registerClass`: `GObject.registerClass({ Signals: { 'my-signal': {} } }, class ...)`
- Emit with matching arg count: `this.emit('my-signal')` for 0-arg signals
- `emit('my-signal', null)` on a 0-arg signal throws `Signal requires 0 args got 1`

## Install for live editing (symlink)
```sh
UUID=name@domain.tld
EXT=~/.local/share/gnome-shell/extensions/$UUID
ln -sfn "$PWD" "$EXT"
# compile schema into BOTH the extension's schemas/ dir AND the user schemas dir
glib-compile-schemas --strict --targetdir=schemas schemas
cp schemas/gschemas.compiled ~/.local/share/glib-2.0/schemas/gschemas.compiled
```

## glib-compile-schemas not on PATH (NixOS)
```sh
GLIB_CS=$(command -v glib-compile-schemas || ls /nix/store/*-glib-*-dev/bin/glib-compile-schemas | head -1)
```

## Enable + reload via DBus
```sh
# DBus interface: org.gnome.Shell.Extensions at /org/gnome/Shell/Extensions
gdbus call --session --dest org.gnome.Shell.Extensions \
  --object-path /org/gnome/Shell/Extensions \
  --method org.gnome.Shell.Extensions.EnableExtension <uuid>
gdbus call --session --dest org.gnome.Shell.Extensions \
  --object-path /org/gnome/Shell/Extensions \
  --method org.gnome.Shell.Extensions.GetExtensionInfo <uuid>
```
- `EnableExtension` returns `(true,)` for known extensions, `(false,)` for unknown
- `GetExtensionInfo` returns `(@a{sv} {},)` (empty dict) for unknown extensions
- `ReloadExtension` is NOT implemented on GNOME 50.2

## Shell scan limitation (Wayland)
- GNOME Shell scans `~/.local/share/gnome-shell/extensions` only at startup
- No DBus method triggers a fresh scan
- A freshly symlinked extension needs a one-time shell restart (log out/in)
- After first scan, `DisableExtension` + `EnableExtension` can toggle live
- `ReloadExtension` not implemented → code edits also need restart on GNOME 50.2
- Pre-add uuid to `enabled-extensions` gsettings so it auto-enables on next login

## UninstallExtension DANGER
- `UninstallExtension` DBus method (and `gnome-extensions uninstall`) FOLLOWS SYMLINKS
- On a symlinked extension, it recursively deletes the REAL source directory including .git
- NEVER call UninstallExtension on a symlinked extension
- To remove: `rm ~/.local/share/gnome-shell/extensions/<uuid>` (removes symlink only)

## gsettings enabled-extensions (pure bash)
```sh
# Parse GLib variant text: ['a','b'] or @as []
parse() { gsettings get org.gnome.shell enabled-extensions | sed "s/^@\w\+\s*\[//; s/^\[//; s/\]$//; s/'//g; s/, /\n/g" | sed '/^$/d'; }
# Rebuild: ['a','b']
join() { local items=() line; while IFS= read -r line || [[ -n "$line" ]]; do [[ -z "$line" ]] && continue; items+=("'$line'"); done; local j; j="$(IFS=,; printf '%s' "${items[*]}")"; printf '[%s]' "$j"; }
# Append idempotent
add() { local list; list="$(parse)"; printf '%s\n' "${list}" | grep -qxF "$UUID" && return 0; gsettings set org.gnome.shell enabled-extensions "$(printf '%s\n%s\n' "${list}" "$UUID" | join)"; }
```

## Debugging
```sh
# Check extension state and errors
gdbus call --session --dest org.gnome.Shell.Extensions \
  --object-path /org/gnome/Shell/Extensions \
  --method org.gnome.Shell.Extensions.GetExtensionErrors <uuid>
gdbus call --session --dest org.gnome.Shell.Extensions \
  --object-path /org/gnome/Shell/Extensions \
  --method org.gnome.Shell.Extensions.GetExtensionInfo <uuid>
# Check journal for stack traces
journalctl --user -b | grep -i "codeburn\|<uuid>" | tail -20
```

## Packaging (CI)
- `gnome-extensions pack` segfaults in Fedora 41 CI. Use manual zip:
```sh
mkdir -p dist/staging/schemas
cp metadata.json extension.js prefs.js *.js stylesheet.css dist/staging/
cp schemas/*.gschema.xml schemas/gschemas.compiled dist/staging/schemas/
cd dist/staging && zip -r ../<uuid>.shell-extension.zip . && cd ../..
```
- `gnome-extensions pack --extra-source=<file>` is needed for helper modules (codeburn.js, ui.js) — without it they're omitted from the zip
- ZIP structure: files at archive root, `schemas/` subdir — no top-level directory wrapper

## CI gotchas
- `[skip ci]` in commit messages permanently poisons the tag — GitLab skips ALL pipelines for that commit. Use `workflow:rules` with `$CI_COMMIT_MESSAGE =~ /^release:.*/` + `when: never` instead
- `CI_REPOSITORY_URL` embeds the CI token (`gitlab-ci-token:[MASKED]@...`). Use `CI_PROJECT_URL` for constructing push URLs
- `python3` not available in `before_script` on Fedora 41 (before `dnf install`). Use `sed` for file patching
- YAML colons in script strings break parsing. Use `|` block scalars for lines containing `:` followed by text
