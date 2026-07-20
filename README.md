# angst

NixOS + home-manager flake for a theme-driven, hot-reloadable desktop environment.

## Structural Partitioning

```
@capabilities/     opt-in NixOS system-level feature modules
@core/             shared base layer for system, home, and virtualization
@domains/          user-space home feature declarations (app/tool configs)
@hosts/            environment descriptors — pure data describing where config runs
@lib/              build system, domain framework, theme linting, flake plumbing
@scripts/          auxiliary shell scripts (repo seeding)
@themes/           color token definitions (5 themes)
@toolchains/       language-domain tooling (runtime, LSP, formatters, linters, grammars)
@tools/vm/         standalone Rust workspace for NixOS VM lifecycle management
```

---

### `@capabilities/` — System Feature Modules

Capabilities are opt-in NixOS modules that wire up system-level features. Each `.nix` file is auto-discovered by `capabilities/default.nix` and unconditionally imported into every NixOS config, gated behind conditionals internally. They are the system-level analogue of domains: where domains declare user-space tools, capabilities declare system services.

| File | Provides |
|---|---|
| `audio.nix` | PipeWire |
| `graphical.nix` | X11, i3 |
| `network.nix` | NetworkManager |
| `container.nix` | Podman |
| `ssh.nix` | OpenSSH server |
| `git.nix` | System-level Git config |
| `search.nix` | FSearch (GNOME) indexer |
| `clipboard.nix` | `wl-clipboard` + `xclip` |
| `monitoring.nix` | System monitoring tools |

Adding a file here wires it into every host automatically — no imports to update.

---

### `@core/` — Shared Base Layer

Core is the shared foundation, split into three concerns:

**`core/system/`** — NixOS-specific shared config imported by every NixOS configuration: Brazilian Portuguese keyboard layout (`br-abnt2`), `America/Sao_Paulo` timezone, `en_US.UTF-8` locale, NetworkManager, Nix flakes + `allowUnfree`, user creation (`joao` with `wheel`/`networkmanager`/`video`/`audio` groups, `nushell` as shell), and `nix-ld` for non-Nix binaries.

**`core/home/`** — home-manager shared config imported by every home-manager profile: JetBrains Mono Nerd Font with fontconfig, SSH config generation from `userConfig`, tree-sitter parser building from toolchain grammars, and the `domain-config.nix` activation that seeds the angst repo into `~/.config/angst`.

**`core/virtualization/`** — Multi-layered VM support bridging system and home:

| File | Role |
|---|---|
| `detect.nix` | Declares `angst.isQemuVm` boolean option |
| `is-qemu-vm.nix` | Detection logic: checks if flake path starts with `/host` (9p host mount indicator), or if a host-mount path exists |
| `runtime.nix` | Conditional bootloader: `systemd-boot` on bare metal, `grub` disabled in VM |
| `vm-profile.nix` | Full QEMU VM profile applied when `isQemuVm = true` — 9p filesystem mounts for the angst repo (`/host/.../proj/angst`), the Nix store (overlay of `ro-store` 9p + `rw-store` tmpfs), and shared/tmp directories for SSH keys and clipboard; SPICE vdagent for copy-paste; runtime SSH authorized key injection; monitor override (`Virtual-1 1920x1080`); stripped-down kernel modules and GPU drivers (`modesetting` for `virtio_gpu`) |
| `vm-variant.nix` | NixOS `virtualization.vmVariant` — 4 vCPUs, 4 GiB RAM, 16 GB disk, `virtio-vga` display, SPICE vdagent chardev, shared directory mapping |
| `specialisation.nix` | Bootable specialisation entry for VM mode without rebuild-vm |
| `host-mount.nix` | Creates `/home/joao/.config/angst` symlink to the host 9p mount path, enabling live editing from inside the VM with changes reflected on the host |

Detection is implicit: inside a QEMU VM the flake path starts with `/host/...` (from the 9p mount), setting `angst.isQemuVm = true`. This cascades through `runtime.nix` (bootloader), `vm-profile.nix` (filesystems, drivers, SSH, monitors), and home-manager activation (config source path resolution).

---

### `@hosts/` — Environment Descriptors

Each host directory is pure data — attribute sets consumed by `lib/build/mkHost.nix` and `lib/build/mkHome.nix`. No logic, no imports — just structure:

```nix
{
  system = "x86_64-linux";
  theme = "miasma";
  user = { username = "joao"; homeDirectory = "/home/joao"; ssh = { ... }; git = { ... }; };
  monitors = { primary = { ... }; secondary = { ... }; };
}
```

The corresponding `home.nix` and `configuration.nix` are thin import trees that enable domains and capabilities. A new machine is a new `hosts/<name>/` directory.

`lib/build/scanHosts.nix` reads the `hosts/` directory and returns all hostnames, used by `mkHost` to construct NixOS configurations for every host in a single `nixosConfigurations` attrset.

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
- **`module.nix`** — Auto-generates home-manager modules: creates `enable` option, installs `meta.package`, calls `mkDomainActivation` for XDG symlinks (unless `meta.customXdg = true`)
- **`activation.nix`** — Produces home-manager activation scripts that symlink `domains/.../config/` → `~/.config/<app>`, with host-mount fallback (`/host/.../angst` for VM)
- **`domain-config.nix`** — Seeds the angst repo into `~/.config/angst` during activation via `scripts/seed-angst-repo.sh`

Managed domains:

| Category | Domains |
|---|---|
| `bar/` | i3status |
| `editor/` | nvim |
| `files/` | yazi |
| `launcher/` | rofi |
| `session/` | x11 |
| `shell/` | nushell, starship |
| `terminal/` | ghostty, zellij, tmux |
| `wm/` | i3 |

---

### `@lib/` — Build System, Domain Framework, and Checks

`lib/` is pure framework — the machinery that makes the flake composable and verifiable:

| Path | Responsibility |
|---|---|
| `lib/build/` | Host and home-manager construction: `mkHost.nix` (NixOS system assembly), `mkHome.nix` (home-manager profile assembly with theme/domain wiring), `scanHosts.nix` (auto-discover host directories) |
| `lib/domains/` | Domain discovery, module generation, activation scripts |
| `lib/checks/` | Evaluation-time validation: `desktop.nix` (i3 + i3status per theme), `shell.nix` (starship + nushell per theme), `theme/` (6-file theme validation suite) |
| `lib/flake/` | Flake output assembly: `checks.nix`, `homeConfigurations.nix`, packages (`angst` CLI, `vm-cli`, devShells), apps (`render`, `watch`, `check`, `lint-*`, `vm`) |
| `lib/home/` | Shared home-manager helpers: `themeModule.nix` (propagates theme tokens into home config), `i3Fragments.nix` (i3 keybinding fragments), `fonts.nix` (font family configuration) |

The theme validation system at `lib/checks/theme/` enforces correctness at evaluation time:

- **`entries.nix`** — Each theme file loads without errors
- **`semanticDistinct.nix`** — ansi.error, ansi.success, ansi.warn, ansi.info all have distinct hex values
- **`rendered.nix`** — Rendered ghostty, starship, nushell, zellij configs contain expected theme tokens (no stale hardcoded colors)
- **`override.nix`** — Theme override propagates into rendered output
- **`context.nix`** — Utility to identify the host's current theme and pick an alternate for override testing
- **`assertions.nix`** — `require`, `requireDistinct`, `requireInfix` helpers

---

### `@themes/` — Color Token Definitions

Each theme is a compact Nix attrset with 13 tokens:

```nix
{
  palette = {
    background = { base, variant };
    surface    = { base, variant };
    foreground = { base, variant };
    accent     = { base, variant };
    dim;
  };
  ansi = { error, warn, info, success };
}
```

`themes/default.nix` normalizes (strips `#`, validates hex, checks completeness via `schema.nix`), then enriches each theme with:

- RGB space-separated variants (`_RGB`) for applications requiring integer colors (i3)

Themes are resolved at eval time via `themesLib.get "miasma"`. Default: `monochrome`.

Available: `catppuccin-mocha`, `miasma`, `monochrome`, `noctis`, `kanagawa`.

---

### `@toolchains/` — Language-Domain Tooling

Toolchains define the complete set of tools for a language domain — not just Neovim support, but everything needed to develop in that language.

Each toolchain file returns via `mkToolchain`:

```nix
mkToolchain {
  runtime   = [ cargo rustc ];        # compilers, interpreters, runtimes
  lsp       = [ rust-analyzer ];      # language servers
  formatter = [ rustfmt ];            # code formatters
  linter    = [ clippy ];             # linters
  tools     = [ gotools ];            # additional tooling
  treesitter = [ tree-sitter-rust ];  # tree-sitter grammars
}
```

`lib/toolchain.nix` translates this into `home.packages` (runtime + LSP + formatter + linter + tools) and `toolchains.treesitterGrammars` (aggregated for tree-sitter setup).

Toolchains are imported by `hosts/<name>/home.nix` and aggregated by `lib/flake/default.nix` into unified runtime, LSP, and formatter package lists plus tree-sitter grammar sets.

Supported: `bash`, `c`, `css`, `docker`, `go`, `html`, `java`, `javascript`, `json`, `lua`, `nix`, `php`, `python`, `rust`, `terraform`, `xml`.

---

### `@tools/vm/` — Standalone Rust VM Workspace

A multi-crate Rust workspace (`vm-core`, `vm-cli`, `vm-mcp`) that manages NixOS VM lifecycle independently of the host config. Integrated as a flake input (`inputs.vm`) to encapsulate its build logic from the Nix config.

Features:
- SSH-based communication (port 2222 forwarded to guest 22)
- Headless mode (`--headless` for CI, `-display gtk` for interactive)
- MCP server for IDE integration
- Automatic SSH key injection (ssh-agent + `~/.ssh/*.pub`)
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
