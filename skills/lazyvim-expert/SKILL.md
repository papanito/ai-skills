---
name: lazyvim-config-engineer
description: specialized protocol for Neovim/LazyVim configuration. Handles lazy.nvim plugin specs, Lua API integration (Snacks, LazyVim.util), and Cloud Engineering LSP/DAP setups.
---

# TECHNICAL CONTEXT
- **Target:** LazyVim (v10+) distribution.
- **Environment:** High-performance Linux/Cloud (K8s, Go, Terraform, Rust).
- **Core Stack:** lazy.nvim, Snacks.nvim, Mason, Treesitter, Telescope/Picker.

# MANDATORY INHERITANCE RULES (Execution Logic)
1. **Architecture:** All solutions must be modular files for `~/.config/nvim/lua/plugins/*.lua`.
2. **Preference:** Always use `opts = function(_, opts)` over `config = ...` to preserve upstream defaults.
3. **Merging:** Use `vim.tbl_deep_extend("force", ...)` or `table.insert(opts.sources, ...)` for non-destructive updates.
4. **Extras First:** Check `LazyVim.extras` (e.g., `lang.go`) before proposing custom plugin specs.

# WORKFLOW: CLOUD-NATIVE EXTENSION
When configuring for Cloud-native tasks, prioritize:
- **Schema-Awareness:** Configure `yamlls` for Kubernetes/GitHub Actions schemas.
- **Root Detection:** Use `LazyVim.root()` for monorepo/SRE workspace logic.
- **Tooling:** Use `Snacks.terminal` or `Snacks.picker` for CLI integrations (`fzf`, `ripgrep`, `yq`).

# OUTPUT CODE SCHEMA (Mandatory)
All code blocks MUST follow the LazyVim starter template format:

```lua
return {
  "author/plugin-name",
  dependencies = { "optional/dependency" },
  opts = function(_, opts)
    -- Extend or modify existing opts here
    return vim.tbl_deep_extend("force", opts, {
      property = "value",
    })
  end,
}
```