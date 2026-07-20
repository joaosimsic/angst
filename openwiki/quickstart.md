# angst — Quickstart

**angst** is a [NixOS](https://nixos.org/) + [home-manager](https://github.com/nix-community/home-manager) flake for a **theme-driven, hot-reloadable desktop environment**.

It manages every layer of the system — from hardware detection and bootloader to shell prompts and editor themes — using a unified color-theme system that propagates across 15+ applications.

## Repository Map

| Area | Purpose |
|------|---------|
| `/local/config.nix` | Machine identity — single file defining hostname, username, theme, profiles, monitors |
| `/profiles/` | Reusable profile compositions (base, desktop, development, server, vm) that enable domains + capabilities |
| `/modules/` | Core NixOS and home-manager modules: `home/`, `nixos/`, `vm/` (detection, runtime) |
| `/domains/` | User-space app configs — the unit of configuration (17 domains) |
| `/themes/` | Color theme definitions (9 themes across 13 tokens, strict schema) |
| `/capabilities/` | Opt-in NixOS system feature modules |
| `/toolchains/` | Declarative dev language toolchains (22 languages) |
| `/tools/` | Rust CLI tools: `shell` (dev shell entry), `vm` (QEMU lifecycle) |
| `/lib/` | Build system, domain framework, flake outputs, config loading, theme rendering |
| `/checks/` | Build-time validation: theme linting, syntax checks, override tests |
| `/scripts/` | Auxiliary shell scripts (repo seeding, password hashing) |
| `/docs/` | Additional documentation (checks, VM usage) |

## Key Concepts

- **Configuration** — A single `local/config.nix` file (gitignored) defines the full machine identity: hostname, username, theme, password, profiles, monitors, NixOS extras, and toolchain selection. No per-host directories, no `.env` file. It replaces the old `hosts/` and `user.env` systems.
- **Profiles** — Reusable composition units (`profiles/base.nix`, `desktop.nix`, `development.nix`, `server.nix`, `vm.nix`) that enable domains and capabilities. A machine selects its profiles via `config.profiles = ["base" "desktop" "development"]`. Profiles use `mkDomainEnable` and `mkCap` helpers to safely reference domains and capabilities.
- **Domains** — The unit of user-space configuration. Each `domains/<category>/<name>/` describes one application with `meta.nix` (package info), `render.nix` (theme-aware config generator), and optionally `module.nix`, `config/` directory, and `nixos.nix`. 17 domains available.
- **Themes** — A compact color token system (palette + ansi) with 13 tokens. All 9 themes are validated at build time.
- **Capabilities** — Opt-in NixOS modules auto-discovered from `/capabilities/`. System-level analogue of domains.
- **Toolchains** — Declarative language environment definitions (runtime, LSP, formatter, linter, tree-sitter grammar). 22 toolchains for languages from bash to rust to markdown.
- **Modules** — Core NixOS and home-manager modules in `modules/home/` (treesitter, domain framework, theme), `modules/nixos/` (font, keyboard layout), and `modules/vm/` (detection, runtime, profile, variant).
- **Hot-reload** — The `angst render`/`angst watch` CLI regenerates theme-rendered configs without a full Nix rebuild.

## Configuration

A single `local/config.nix` file defines the full machine environment:

```nix
{
  system = "x86_64-linux";
  hostname = "nixos";
  username = "joao";
  theme = "miasma";
  profiles = ["base" "desktop" "development"];   # profile composition
  toolchains = "*";                                # all languages
  password = "$y$j9T$...";                         # hashed, NOT plaintext
  monitors = {
    primary = { name = "DP-1"; resolution = "1920x1080"; ... };
  };
  nixos = { keyboardLayout = "br-abnt2"; };        # per-machine extras
}
```

Start from `local/config.nix.example` — copy it, edit, and the build system (`lib/read-config.nix`) loads it automatically. No per-host directories, no `.env` parsing.

## Getting Started

### Build and activate your configuration

```bash
# Build the NixOS config (reads local/config.nix for hostname/profiles)
nixos-rebuild switch --flake .#current

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

## Profiles

| Profile | Includes | Domains | Capabilities |
|---------|----------|---------|-------------|
| `base` | Always applied | nushell, carapace, starship, zellij, nvim, yazi, lazygit | network, git, search, monitoring, container |
| `desktop` | Workstation GUI | i3, i3status, rofi, ghostty, x11 | graphical, audio, clipboard |
| `development` | Dev tooling | opencode, cursor-cli, sqlit, posting | — |
| `server` | Headless server | — | ssh |
| `vm` | QEMU VM overlay | — | vm detection + runtime + profile + ssh |

Profiles are composed via `profiles = ["base" "desktop" "development"]` in `local/config.nix`. Each profile uses `mkDomainEnable` and `mkCap` helpers that validate domain/capability names at build time.

## Quick Links

- [Architecture](architecture.md) — Flake structure, build system, configuration, profiles, capabilities, VM detection
- [Domains](domains.md) — Domain framework, 17 available domains, toolchains (22 langs)
- [Themes](themes.md) — Theme schema, 13 tokens, 9 themes, validation, domain integration
- [Tools](tools.md) — CLI tools: angst, shell, vm, OpenCode MCP
- [Operations](operations.md) — Dev shells, checks/CI, VM workflow, hot-reload, lint/format

## Change Guidance

When working on this repository, follow these guidelines:

- **Configuring a machine**: Edit `local/config.nix` — set hostname, username, theme, and compose profiles. No per-host directory is needed. Start from `local/config.nix.example`.
- **Adding a profile composition**: Create `profiles/<name>.nix` using `mkDomainEnable` and `mkCap` helpers, then add it to `profiles/default.nix`'s `profileMap`. Reference it in `config.profiles` in `local/config.nix`.
- **Adding a new domain**: Create `domains/<category>/<name>/meta.nix`, optionally `render.nix` (theme-aware config), `module.nix` (custom logic), `config/` (static files), and/or `nixos.nix` (system integration). Enable via profile composition or local config extras.
- **Adding a new theme**: Create `/themes/<name>.nix` following the schema in `/themes/schema.nix`. Validate with `nix run .#lint-themes`.
- **Adding a new toolchain**: Create `/toolchains/<name>.nix` using `mkToolchain`. Auto-discovered and included in dev shells.
- **Changing renders**: Edit `render.nix` in the domain, then run `angst render` to write configs. Run `nix run .#lint-shell` or `nix run .#lint-desktop` to validate.
- **Modifying the domain framework**: `/lib/domains/scan.nix` (discovery), `/lib/domains/module.nix` (auto-module generation), `/lib/domains/activation.nix` (XDG symlinks).
- **Before committing**: Run `nix run .#check` (full suite) or at minimum `nix run .#lint-themes`.

### Key Source Files by Concern

| Concern | Files |
|---------|-------|
| Flake orchestration | `/flake.nix` |
| Flake outputs | `/lib/flake/outputs.nix` |
| Home-manager build | `/lib/build/mkHome.nix` |
| NixOS build | `/lib/build/mkNixos.nix` |
| Config loading | `/lib/read-config.nix`, `/local/config.nix` |
| Profile composition | `/profiles/default.nix`, `/profiles/base.nix`, `desktop.nix`, `development.nix`, `server.nix`, `vm.nix` |
| Domain framework | `/lib/domains/scan.nix`, `/lib/domains/module.nix`, `/lib/domains/activation.nix` |
| Theme system | `/themes/default.nix`, `/themes/schema.nix` |
| Theme validation | `/checks/theme/` (7 files) |
| VM infrastructure | `/modules/vm/*.nix` (7 files) |
| Rust shell CLI | `/tools/shell/src/` |
| Rust VM CLI | `/tools/vm/Cargo.toml`, `/tools/vm/crates/` |
| Render system | `/lib/render.nix` |
