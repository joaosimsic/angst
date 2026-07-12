# angst — Quickstart

**angst** is a [NixOS](https://nixos.org/) + [home-manager](https://github.com/nix-community/home-manager) flake for a **theme-driven, hot-reloadable desktop environment**.

It manages every layer of the system — from hardware detection and bootloader to shell prompts and editor themes — using a unified color-theme system that propagates across 15+ applications.

## Repository Map

| Area | Purpose |
|------|---------|
| `/hosts/` | Machine definitions (pure data: system, theme, user, monitors) |
| `/domains/` | User-space app configs — the unit of configuration |
| `/themes/` | Color theme definitions (5 themes, strict schema) |
| `/capabilities/` | Opt-in NixOS system feature modules |
| `/toolchains/` | Declarative dev language toolchains (18 languages) |
| `/tools/` | Rust CLI tools: `shell` (dev shell entry), `vm` (QEMU lifecycle) |
| `/lib/` | Build system, domain framework, theme linting, flake plumbing |
| `/common/` | Shared config fragments (user, capabilities, home imports) |
| `/scripts/` | Auxiliary shell scripts (repo seeding) |
| `/docs/` | Additional documentation (checks, VM usage) |

## Key Concepts

- **Domains** — The unit of user-space configuration. Each `domains/<category>/<name>/` describes one application with `meta.nix` (package info), `render.nix` (theme-aware config generator), and optionally `module.nix`, `config/` directory, and `nixos.nix`.
- **Themes** — A compact color token system (palette + ansi) with 13 tokens. All 5 themes are validated at build time.
- **Capabilities** — Opt-in NixOS modules auto-discovered from `/capabilities/`. System-level analogue of domains.
- **Hosts** — Pure-data machine descriptors in `/hosts/<name>/`. Each defines system arch, theme, user info, monitors. No logic.
- **Toolchains** — Declarative language environment definitions (runtime, LSP, formatter, linter, tree-sitter grammar).
- **Hot-reload** — The `angst render`/`angst watch` CLI regenerates theme-rendered configs without a full Nix rebuild.

## Getting Started

### Build and activate your host configuration

```bash
# Build the NixOS config for your host
nixos-rebuild switch --flake .#personal

# Or build just the home-manager profile
home-manager switch --flake .#joao
```

### Enter a development shell

```bash
# Safe editing environment (neovim, parsers, LSPs)
nix develop .#safe

# Full development environment (safe + Rust, QEMU, angst CLI, VM tools)
nix develop .#dev
```

### Use the shell CLI (standalone, no nix at runtime)

```bash
# Install globally
nix profile install .#shell

# Enter dev or safe mode
shell dev
shell safe
```

### Render and watch configs

```bash
# Render all domain configs for current host/theme to ~/.config/
angst render

# Watch for changes and re-render
angst watch
```

### Run checks

```bash
# Full check suite (equivalent to nix flake check)
nix run .#check

# Targeted checks
nix run .#lint-themes
nix run .#lint-desktop
nix run .#lint-shell
```

## Hosts

| Host | Type | Theme | Config |
|------|------|-------|--------|
| `personal` | Physical workstation (AMD, dual monitor, i3) | miasma | `/hosts/personal/` |
| `ssh` | Headless server (SSH-only) | miasma | `/hosts/ssh/` |

## Quick Links

- [Architecture](architecture.md) — Flake structure, build system, hosts, capabilities, VM detection
- [Domains](domains.md) — Domain framework, available domains, toolchains, common config
- [Themes](themes.md) — Theme schema, tokens, validation, domain integration
- [Tools](tools.md) — CLI tools: angst, shell, vm, OpenCode MCP
- [Operations](operations.md) — Dev shells, checks/CI, VM workflow, hot-reload, lint/format

## Change Guidance

When working on this repository, follow these guidelines:

- **Adding a new host**: Create `hosts/<name>/` with `default.nix` (pure data), `configuration.nix` (NixOS), `hardware.nix`, and `home.nix` (domain enables). Auto-discovered by `/lib/build/scanHosts.nix`.
- **Adding a new domain**: Create `domains/<category>/<name>/meta.nix`, optionally `render.nix` (theme-aware config), `module.nix` (custom logic), `config/` (static files), and/or `nixos.nix` (system integration). Enable in host's `home.nix` or `/common/home.nix`.
- **Adding a new theme**: Create `/themes/<name>.nix` following the schema in `/themes/schema.nix`. Validate with `nix run .#lint-themes`.
- **Adding a new toolchain**: Create `/toolchains/<name>.nix` using `mkToolchain`. Auto-discovered and included in dev shells.
- **Changing renders**: Edit `render.nix` in the domain, then run `angst render` to write configs. Run `nix run .#lint-shell` or `nix run .#lint-desktop` to validate.
- **Modifying the domain framework**: `/lib/domains/scan.nix` (discovery), `/lib/domains/module.nix` (auto-module generation), `/lib/domains/activation.nix` (XDG symlinks).
- **Before committing**: Run `nix run .#check` (full suite) or at minimum `nix run .#lint-themes`.

### Key Source Files by Concern

| Concern | Files |
|---------|-------|
| Flake orchestration | `/flake.nix` |
| Flake outputs | `/lib/flake/default.nix`, `/lib/flake/shared.nix` |
| Home-manager build | `/lib/build/mkHome.nix` |
| NixOS build | `/lib/build/mkHost.nix` |
| Domain framework | `/lib/domains/scan.nix`, `/lib/domains/module.nix`, `/lib/domains/activation.nix` |
| Theme system | `/themes/default.nix`, `/themes/schema.nix` |
| Theme validation | `/lib/checks/theme/` (6 files) |
| VM infrastructure | `/lib/virtualisation/*.nix` (8 files) |
| Rust shell CLI | `/tools/shell/src/` |
| Rust VM CLI | `/tools/vm/Cargo.toml`, `/tools/vm/src/` |
