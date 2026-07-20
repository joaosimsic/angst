# angst

NixOS + home-manager flake for a theme-driven, hot-reloadable desktop environment.

All configuration is driven by a single `local/config.nix` file:

```nix
{
  hostname = "nixos";
  username = "joao";
  theme = "miasma";
  profiles = ["base" "desktop" "development"];   # composes modules + domains + caps
  toolchains = "*";                                # all 22 languages, or a list
  password = "$y$j9T$...";                         # hashed via `just password`
  monitors = { primary = { ... }; };
  nixos = { keyboardLayout = "br-abnt2"; };        # per-machine extras
}
```

Start from `local/config.nix.example`. The build system (`lib/read-config.nix`) loads this file and produces a unified `cfg` object consumed by every builder. See [openwiki/quickstart.md](openwiki/quickstart.md).

## Structural Partitioning

```
@capabilities/     opt-in NixOS system-level feature modules
@checks/           build-time validation (theme lint, config rendering, Nix syntax)
@domains/          user-space home feature declarations (app/tool configs)
@lib/              build system, domain framework, config loading, flake outputs
@local/            machine-specific identity file + hardware config (gitignored)
@modules/          core NixOS/home/VM modules (replaces old @core/)
@profiles/         reusable profile compositions — select via local/config.nix
@scripts/          auxiliary shell scripts (repo seeding, password hashing)
@themes/           color token definitions (9 themes, strict schema)
@toolchains/       language-domain tooling (22 languages, runtime/LSP/formatter/linter)
@tools/vm/         standalone Rust workspace for NixOS VM lifecycle management
```

---

### `@capabilities/` — System Feature Modules

Capabilities are opt-in NixOS modules that wire up system-level features. Each `.nix` file is auto-discovered by `capabilities/default.nix`. They are the system-level analogue of domains: where domains declare user-space tools, capabilities declare system services. Capabilities are enabled through **profile composition** — each profile uses `mkCap` to activate the capabilities it needs.

| File | Provides |
|---|---|
| `audio.nix` | PipeWire with ALSA/PulseAudio compat |
| `graphical.nix` | X11, LightDM (themed background), libinput, dbus, XDG portals |
| `network.nix` | NetworkManager, wget, curl, unzip |
| `container.nix` | Docker, Podman, kubectl, lazydocker |
| `ssh.nix` | OpenSSH server, key-only auth, agent forwarding |
| `git.nix` | System-level Git config |
| `search.nix` | FSearch (GNOME) indexer |
| `clipboard.nix` | `wl-clipboard` + `xclip` |
| `monitoring.nix` | System monitoring tools |

Capability enable + import is managed by `mkCap` in `profiles/default.nix`. The `base` profile enables `network`, `git`, `search`, `monitoring`, `container`; the `desktop` profile adds `graphical`, `audio`, `clipboard`.

---

### `@checks/` — Build-Time Validation

Build-time checks are defined in `checks/` (formerly under `lib/checks/`). Each is a NixOS or home-manager evaluation that validates theme correctness, config rendering, and override propagation.

| Check | What it validates |
|---|---|
| `theme/entries.nix` | Each theme file loads without errors |
| `theme/semanticDistinct.nix` | `ansi.error`, `ansi.success`, `ansi.warn`, `ansi.info` are all distinct |
| `theme/rendered.nix` | Rendered domain configs contain correct theme tokens |
| `theme/override.nix` | Theme override propagates into rendered output |
| `desktop.nix` | i3 + i3status configs per theme |
| `shell.nix` | starship + nushell configs per theme |
| `lint-nix.nix` | Statix Nix lint |
| `password.nix` | Password hash validation |

Run `nix flake check` or individual checks via `nix run .#lint-themes`, `nix run .#lint-desktop`, `nix run .#lint-shell`.

---

### `@domains/` — Home Feature Declarations

Domains are the unit of user-space configuration. Each `domains/<category>/<name>/` describes one application:

| File | Purpose |
|---|---|
| `meta.nix` | Schema: Nix package name, XDG target (`xdg` for full directory, `xdgFile` for single file), description |
| `module.nix` | (optional) Custom home-manager module; most domains use the auto-generated module from `lib/domains/module.nix` |
| `render.nix` | Theme-aware config generator: `{ themesLib, themeName, fontFamily } → [{ path, text }]` |
| `nixos.nix` | (optional) System-level module for domains needing NixOS integration (e.g., i3) |

The domain framework in `lib/domains/` provides:

- **`scan.nix`** — Recursively discovers all domain directories and parses `meta.nix`
- **`module.nix`** — Auto-generates home-manager modules: creates `enable` option, installs `meta.package`, calls `mkDomainActivation` for XDG symlinks
- **`activation.nix`** — Produces home-manager activation scripts that symlink `domains/.../config/` → `~/.config/<app>`, with VM host-mount fallback

17 domains across 12 categories — see [openwiki/domains.md](openwiki/domains.md) for the full table.

Domain categories: `agents/` (opencode, cursor-cli), `bar/` (i3status), `editor/` (nvim), `files/` (yazi), `git/` (lazygit), `http-client/` (posting), `launcher/` (rofi), `session/` (x11), `shell/` (nushell, starship, carapace), `sql-client/` (sqlit), `terminal/` (ghostty, zellij, tmux), `wm/` (i3).

Domains are enabled via **profile composition** (in `profiles/`), not per-host `home.nix` files.

---

### `@lib/` — Build System, Domain Framework, and Flake Outputs

`lib/` is pure framework — the machinery that makes the flake composable and verifiable:

| Path | Responsibility |
|---|---|
| `lib/build/mkNixos.nix` | NixOS system constructor (receives `cfg` object, wires profiles + modules + VM detection + hardware) |
| `lib/build/mkHome.nix` | Home-manager profile constructor (cfg-based, no user.env parsing) |
| `lib/domains/` | Domain discovery, module generation, activation scripts |
| `lib/flake/outputs.nix` | All flake outputs: home configs, NixOS configs, packages, dev shells, apps, checks |
| `lib/flake/devshell.nix` | Dev shell definitions (safe, dev) with SSH agent init |
| `lib/read-config.nix` | Loads `local/config.nix` and produces unified `cfg` object |
| `lib/render.nix` | Theme rendering engine (`renderDomainOutputsFor`, etc.) |
| `lib/toolchain.nix` | `mkToolchain` builder — translates toolchain attrsets into packages + grammars |
| `lib/treesitter.nix` | Tree-sitter grammar builder for cross-glibc compatibility |
| `lib/nixpkgs-config.nix` | Nixpkgs config (`allowUnfree`) |

---

### `@local/` — Machine Identity (gitignored)

| File | Purpose |
|---|---|
| `config.nix` (gitignored) | Full machine identity — hostname, username, theme, profiles, monitors, extras |
| `config.nix.example` | Template with comments |
| `hardware.nix` | Generated hardware config (auto-imported by `mkNixos.nix`) |

No per-host directories, no `.env` file — everything lives in one gitignored file at `local/config.nix`.

---

### `@modules/` — Core Home, NixOS, and VM Modules

Replaces the old `@core/` directory. Three subdirectories:

**`modules/nixos/`** — Base NixOS system config imported by every configuration: keyboard layout, `America/Sao_Paulo` timezone, `en_US.UTF-8` locale, NetworkManager, Nix flakes + `allowUnfree`, user creation, `nix-ld`, and root filesystem default.

**`modules/home/`** — Base home-manager config: username, fonts, SSH config generation, tree-sitter parser building, domain framework integration, and theme option definition.

**`modules/vm/`** — Multi-layered VM support: detection (9p path based), conditional bootloader, QEMU VM profile (9p mounts, SPICE, SSH keys), vmVariant resources, bootable specialisation, and host-mount symlink for live editing.

---

### `@profiles/` — Reusable Composition Units

Profiles replace host-specific `home.nix` and `configuration.nix` files. Each profile returns `{ hm = [...]; nixos = [...]; }` module lists:

| Profile | Domains | Capabilities |
|---|---|---|
| `base.nix` | nushell, carapace, starship, zellij, nvim, yazi, lazygit | network, git, search, monitoring, container |
| `desktop.nix` | i3, i3status, rofi, ghostty, x11 | graphical, audio, clipboard |
| `development.nix` | opencode, cursor-cli, sqlit, posting | — |
| `server.nix` | — | ssh |
| `vm.nix` | — | vm detection + runtime + profile + ssh |

Select via `profiles = ["base" "desktop" "development"]` in `local/config.nix`.

---

### `@themes/` — Color Token Definitions

9 themes, each a compact Nix attrset with 13 tokens (palette + ansi: `{ background, surface, foreground, accent, dim, error, warn, info, success }`). Available: `catppuccin-mocha`, `github`, `gotham`, `kanagawa`, `lotus`, `miasma`, `monochrome` (default), `noctis`, `rose-pine`.

`themes/default.nix` normalizes (strips `#`, validates hex), then enriches with RGB variants (`_RGB`) for apps like i3 that need integer colors.

Themes are resolved at eval time via `themesLib.get "miasma"`. See [openwiki/themes.md](openwiki/themes.md).

---

### `@toolchains/` — Language-Domain Tooling

22 language toolchains defined via `mkToolchain`. Each provides runtime, LSP, formatter, linter, tools, and tree-sitter grammar entries.

Supported: `bash`, `blade`, `c`, `clojure`, `conf`, `css`, `docker`, `go`, `html`, `java`, `javascript`, `json`, `just`, `lua`, `markdown`, `nix`, `php`, `python`, `rust`, `terraform`, `toml`, `xml`.

Toolchains are auto-discovered by `lib/read-config.nix` and filtered by `config.toolchains` in `local/config.nix`. Packages flow into home-manager and dev shells; grammars flow into tree-sitter setup via `lib/treesitter.nix`.

---

### `@tools/vm/` — Standalone Rust VM Workspace

A multi-crate Rust workspace (`vm-core`, `vm-cli`, `vm-mcp`) that manages NixOS VM lifecycle independently of the host config. Integrated as a flake input (`inputs.vm`).

Features:
- SSH-based communication (port 2222 forwarded to guest 22)
- Headless mode (`--headless` for CI, `-display gtk` for interactive)
- MCP server for AI agent integration
- Automatic SSH key injection (ssh-agent + `~/.ssh/*.pub`)
- 15 CLI commands: `build`, `start`, `stop`, `restart`, `ssh`, `exec`, `scp`, `health`, `status`, `logs`, `snapshot`, `restore`, `mcp`, `list`, `info`

See [openwiki/tools.md](openwiki/tools.md) and [openwiki/operations.md](openwiki/operations.md).
- QEMU disk image management (`personal.qcow2`)

---

### Data Flow

```
hosts/<name>/default.nix              # pure data: theme, user, monitors
       │
       ▼
lib/build/mkHome.nix                  # loads theme (themesLib.get), resolves domains
       │
       ▼
domains/<cat>/<name>/render.nix       # each domain: theme tokens → [{ path, text }]
       │
       ▼
nix run .#render                       # writes to domains/<cat>/<name>/config/
       │
       ▼
home-manager activation                # symlinks config/ → ~/.config/<app>
```

---

### Usage

```bash
# Build and activate home-manager profile
nix run .#angst

# Render all domain config files for the current theme/host
nix run .#render

# Watch themes/domains/hosts for changes and hot-reload
nix run .#watch

# Full evaluation-time validation suite
nix run .#check

# Targeted lints (faster)
nix run .#lint-themes    # eval-only theme validation
nix run .#lint-desktop   # i3 + i3status per theme
nix run .#lint-shell     # starship + nushell per theme

# VM lifecycle
nix run .#vm             # CLI tool (start, stop, ssh, restart)
nix run .#vm-run         # Script-based VM launcher
nix run .#vm -- --headless  # headless mode for CI

# Development shells
nix develop .#safe  # safe environment (neovim, LSPs, formatters, no dev tools)
nix develop .#dev   # full development environment (adds VM CLI, angst, Rust)
nix develop .#vm    # Rust tooling for the VM workspace

# Shell CLI (standalone — no nix needed at runtime)
nix run .#shell -- safe  # enter safe environment
nix run .#shell -- dev   # enter development environment
```

### CI

`.github/workflows/checks.yml` runs `nix flake check` (theme validation, desktop/shell linting, NixOS evaluation) and `cargo fmt + cargo test` for the VM tool on every push and PR.
