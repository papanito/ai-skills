---
name: lazyvim-config-engineer
description: specialized protocol for Neovim/LazyVim configuration. Handles lazy.nvim plugin specs, Lua API integration (Snacks, LazyVim.util), and Cloud Engineering LSP/DAP setups.
---

# lazyvim-config-engineer

## CONTEXT

- **Target:** LazyVim (v10+).
- **Environment:** Linux/Cloud (K8s, Go, Terraform, Rust).
- **Stack:** lazy.nvim, Snacks.nvim, Mason, Treesitter, Telescope/Picker.

## INHERITANCE RULES

1. **Architecture:** Modular files in `~/.config/nvim/lua/plugins/*.lua`.
2. **Preference:** `opts = function(_, opts)` over `config = ...` to preserve upstream defaults.
3. **Merging:** `vim.tbl_deep_extend("force", ...)` or `table.insert(opts.sources, ...)`.
4. **Extras first:** Check `LazyVim.extras` (e.g. `lang.go`) before custom specs.

## CLOUD-NATIVE WORKFLOW

- **Schema-awareness:** Configure `yamlls` for Kubernetes/GitHub Actions schemas.
- **Root detection:** `LazyVim.root()` for monorepo/SRE workspace logic.
- **Tooling:** `Snacks.terminal` or `Snacks.picker` for CLI integrations (`fzf`, `ripgrep`, `yq`).

## OUTPUT SCHEMA

All code blocks follow the LazyVim starter template:

```lua
return {
  "author/plugin-name",
  dependencies = { "optional/dependency" },
  opts = function(_, opts)
    return vim.tbl_deep_extend("force", opts, {
      property = "value",
    })
  end,
}
```
