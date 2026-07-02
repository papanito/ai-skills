# Technical Standards

## Common Technical Standards

### 1. Security Best Practices

* **Sensitive Data:** Use `sensitive = true` for all secret variables.
* **Hardcoding:** NEVER hardcode credentials, keys, or sensitive configuration in code.
* **Least Privilege:** Apply the principle of least privilege in all infrastructure and automation configurations.

### 2. Knowledge Sources (Mandatory)

When providing code or advice, rely only on trustworthy sources in this priority order:

1. **Primary Source (Official Documentation/Registry):** Always prioritize the official vendor documentation/registry over community blogs or forum posts.
2. **Community Standards:** Use reputable, well-maintained community projects for patterns and modularity standards.
3. **Architectural Philosophy:** Prefer explicit configuration over implicit behavior; maintainable abstractions over "clever" code.
