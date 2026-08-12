# angst — Quickstart

**angst** is a [NixOS](https://nixos.org/) + [home-manager](https://github.com/nix-community/home-manager) flake for a **theme-driven, hot-reloadable desktop environment**. It manages every layer of the system — from hardware detection and bootloader to shell prompts and editor themes — through one unified color-theme system that propagates across ~21 user-space applications.

Machines are declared as plain, diffable Nix files under `hosts/` and auto-discovered at flake eval time. Secrets live in per-host, sops-encrypted `secrets.yaml` files and are decrypted at runtime by sops-nix — never in the repo.

> The [README.md](../README.md) is maintained in sync with this wiki; when a page here and the README disagree, this wiki (grounded in `hosts/` + `lib/`) is the reference for recent changes.

## Repository Map

| Area | Purpose |
|------|---------|
| `/hosts/` | Machine declarations: `hosts/<domain>/<hostname>/default.nix` (+ optional `secrets.yaml`, `hardware.nix`) |
| `/profiles/` | Reusable composition units (base, desktop, development, server, vm) selected per host |
| `/modules/` | Core modules: `home/`, `nixos/`, `vm/`, plus `secrets.nix` (sops integration) |
| `/domains/` | Features — the unit of configuration (31 features / 17 categories), each with a `default.nix` interface + optional `home.nix`/`system.nix` sides |
| `/projects/` | Encrypted dev-project store (sops binary, opaque ids, scope-isolated age keys) synced by `angst projects` |
| `/themes/` | Color token definitions (9 themes, strict 13-token schema) |
| `/toolchains/` | Declarative dev-language toolchains (23 languages via `mkToolchain`) |
| `/tools/` | Standalone Rust workspaces: `shell` (env switcher), `vm` (QEMU lifecycle + MCP) |
| `/lib/` | Build system: `discover.nix`, `resolve.nix`, `build/`, `domains/`, `flake/`, `render.nix`, `treesitter.nix` |
| `/checks/` | Build-time validation (theme lint, rendered configs, password, secrets, login-shell, Nix lint) |
| `/scripts/` | `angst.sh` (render/watch/bootstrap-secrets), `analyze_flake/` (analysis.md generator) |
| `/githooks/` | gitleaks pre-commit / pre-push hooks (install via `just install-hooks`) |

## Key Concepts

- **Hosts** — Each machine is `hosts/<domain>/<hostname>/default.nix`, a pure data decl (`type`, hostname, username, theme, profiles, toolchains, monitors, sshAgent, persist, …). `lib/discover.nix` finds them recursively; `lib/resolve.nix` normalizes each decl into a `host` object. Optional `secrets.yaml` (sops-encrypted) and `hardware.nix` sit next to the decl. Current hosts: `ci` (CI runner), `personal/nixos` (desktop), `personal/mint` (home-only, `type = "home"`), `vm`.
- **Profiles** — Composition units (`profiles/*.nix`), each a pure feature list `{ enable = [...]; }` (+ optional NixOS-only `modules`). Hosts select via `profiles = ["base" "desktop" ...]`. `profiles/default.nix` validates feature names at build time and the builder splits them into home/system sides by feature sides + host type.
- **Domains** — The unit of configuration: `domains/<category>/<name>/` with a `default.nix` interface (package + XDG target + description, validated by `mkDomain`), optional `home.nix` (home-manager), `system.nix` (NixOS), `render.nix` (theme-aware config generator), and `config/`. A feature may be user-space, system-space, or both. Auto-discovered and turned into modules by `lib/domains/`.
- **Themes** — 13 color tokens (9 palette + 4 ansi). 9 themes, all validated at build time; rendered into every domain config. See [Themes](themes.md).
- **Toolchains** — Declarative language environments (runtime, LSP, formatter, linter, treesitter grammar) for 23 languages; selected by `toolchains = "*"` or a list in the host decl.
- **Secrets** — sops-nix + age. `secrets.yaml` per host holds `masterPassword` (+ app keys such as `opencodeGoKey`); decrypted at runtime into `~/.secrets/` and used to bootstrap login hashes and the SSH key passphrase. See [Secrets](secrets.md).
- **Projects** — `angst projects` syncs declared dev repos into `~/projects/` with encrypted `.env` handling that survives a public repo: a `projects/` store holds sops-binary `metadata.yaml` + `env` under opaque ids, split into `personal`/`work` scopes encrypted to different age keys. `sync` runs at home activation and as a `systemd.user` oneshot. See [Domains](domains.md#gitprojects--encrypted-project-store) and [Secrets](secrets.md#project-store).
- **Hot-reload** — `angst render` / `angst watch` regenerate theme-rendered configs without a full Nix rebuild.

## Getting Started

### Build and activate a machine

```bash
# Build the NixOS config for a host (reads hosts/<domain>/<host>/default.nix)
nixos-rebuild switch --flake .#nixos

# Just build it
nix build .#nixosConfigurations.nixos

# Home-manager only (also works for type = "home" hosts like mint)
nix build .#homeConfigurations.joao.activationPackage && ./result/activate
# or via just:
just hm-switch host="nixos"
```

Hosts are auto-discovered: adding `hosts/<domain>/<name>/default.nix` is enough — no `flake.nix` edits.

### Enter a development shell

```bash
nix develop .#safe   # safe editing env (neovim, parsers, LSPs, formatters)
nix develop .#dev    # full dev env (adds angst CLI, qemu, sops, age, gitleaks, Rust, VM tools)
nix develop .#vm     # Rust tooling for the tools/vm workspace
```

### Standalone shell CLI (no nix at runtime)

```bash
nix profile install .#shell   # or: nix run .#shell -- dev
shell dev                     # enter the dev environment
shell safe                    # enter the safe environment
```

### Render and watch configs

```bash
angst render                      # render all domain configs for current host/theme
angst watch                       # watchexec-based re-render on themes/domains/hosts changes
angst render --host vm --no-reload
```

### Run checks

```bash
nix flake check                    # full suite (or: nix run .#check)
nix run .#lint-themes              # theme validation (fast, eval-only)
nix run .#lint-desktop             # i3 + i3status per theme
nix run .#lint-shell               # starship + nushell per theme
```

## Profiles

| Profile | Features (`enable`) |
|---------|---------------------|
| `base` | nushell, carapace, starship, zellij, nvim, yazi, lazygit, nh, age, sops, network, git, search, monitoring, container, ssh |
| `desktop` | rofi, ghostty, x11, graphical, audio, clipboard |
| `development` | opencode, cursor-cli, sqlit, rainfrog, posting, git.projects |
| `server` | ssh (sshd driven per-host via `host.ssh.server.enable`) |
| `vm` | ssh + VM modules (detect, runtime, variant, profile, host-mount) |

## Quick Links

- [Architecture](architecture.md) — flake inputs/outputs, host discovery + resolution, build pipeline, VM support, impermanence, dead code
- [Secrets](secrets.md) — sops/age architecture, master-password bootstrap, VM key forwarding, secret scanning
- [Domains](domains.md) — domain framework, full 21-domain table, toolchains (23 langs), tree-sitter
- [Themes](themes.md) — 13-token schema, 9 themes, normalization/validation, rendering
- [Tools](tools.md) — angst CLI, shell CLI, VM tool + MCP server, analysis script
- [Operations](operations.md) — dev shells, checks/CI, hooks, justfile recipes, VM workflow, runbook

## Change Guidance

- **Configuring a machine**: edit `hosts/<domain>/<hostname>/default.nix` (or create a new host dir — it is auto-discovered). Set theme, profiles, toolchains, monitors, persist, sshAgent. For secrets, run `angst bootstrap-secrets --host <host>`.
- **Adding a profile**: create `profiles/<name>.nix` as a feature list `{ enable = [...]; }` and register it in the `profileMap` in `profiles/default.nix`.
- **Adding a domain**: create `domains/<category>/<name>/default.nix` (the interface), optionally `home.nix`, `system.nix`, `render.nix`, `config/`. Enable via a profile or host extra modules.
- **Adding a theme**: create `/themes/<name>.nix` following `/themes/schema.nix`; validate with `nix run .#lint-themes`.
- **Adding a toolchain**: create `/toolchains/<name>.nix` using `mkToolchain`; auto-discovered by `lib/resolve.nix`.
- **Changing renders**: edit the domain's `render.nix`, then `angst render`; validate with `nix run .#lint-shell` / `.#lint-desktop` / `.#lint-themes`.
- **Modifying the domain framework**: `/lib/domains/mkDomain.nix` (interface validation), `/lib/domains/scan.nix` (discovery), `/lib/domains/module.nix` (auto-module generation).
- **Before committing**: hooks (gitleaks) are installed via `just install-hooks`; CI runs `nix flake check`, gitleaks + trufflehog scanning, nvim tests, and `cargo fmt`/`cargo test` for `tools/vm`. Locally: `nix flake check` at minimum `nix run .#lint-themes`.

### Key Source Files by Concern

| Concern | Files |
|---------|-------|
| Flake orchestration | `/flake.nix` |
| Host discovery | `/lib/discover.nix` |
| Host resolution (decl → host) | `/lib/resolve.nix` |
| Flake outputs | `/lib/flake/outputs.nix` |
| Home-manager build | `/lib/build/mkHome.nix` |
| NixOS build | `/lib/build/mkNixos.nix` |
| Secrets (sops-nix) | `/modules/secrets.nix`, `/modules/home/secrets-activation.nix`, `/scripts/angst.sh` |
| Profile composition | `/profiles/default.nix`, `/profiles/{base,desktop,development,server,vm}.nix` |
| Domain framework | `/lib/domains/mkDomain.nix`, `/lib/domains/scan.nix`, `/lib/domains/module.nix` |
| Theme system | `/themes/default.nix`, `/themes/schema.nix` |
| VM support | `/modules/vm/*.nix` (7 files) |
| Rust shell CLI | `/tools/shell/src/` |
| Rust VM CLI + MCP | `/tools/vm/crates/{vm-cli,vm-core,vm-mcp}/` |
| Render system | `/lib/render.nix`, `/scripts/angst.sh` |
