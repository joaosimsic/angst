# angst

NixOS + home-manager flake for a theme-driven, hot-reloadable desktop environment.

Every machine is declared as a plain, diffable Nix file under `hosts/` and auto-discovered at flake eval time — no `flake.nix` edits, no env-file hacks. Secrets live in per-host, sops-encrypted `secrets.yaml` files and are decrypted at runtime by sops-nix. A single color-theme system propagates across ~21 user-space applications.

Maintained reference documentation lives in [openwiki/](openwiki/quickstart.md) (quickstart, [architecture](openwiki/architecture.md), [domains](openwiki/domains.md), [themes](openwiki/themes.md), [tools](openwiki/tools.md), [operations](openwiki/operations.md), [secrets](openwiki/secrets.md)).

## Quick Start

```bash
# Build + switch a NixOS host (hostname comes from hosts/<domain>/<hostname>/default.nix)
nixos-rebuild switch --flake .#nixos

# Home-manager only (also for type = "home" hosts like mint)
just hm-switch host=nixos            # or: nix build .#homeConfigurations.joao.activationPackage && ./result/activate

# Development shells
nix develop .#safe                   # editing env: neovim, parsers, LSPs, formatters
nix develop .#dev                    # full env: angst CLI, qemu, sops, age, gitleaks, Rust, VM tools
nix develop .#vm                     # Rust tooling for tools/vm

# Render theme-aware configs (no Nix rebuild needed)
angst render                         # write all rendered domain configs
angst watch                          # watchexec hot-reload on themes/domains/hosts changes

# Validation
nix flake check                      # full suite
nix run .#lint-themes                # fast, eval-only theme check
```

## Structural Partitioning

```
@hosts/          machine declarations (hosts/<domain>/<hostname>/default.nix) — auto-discovered
@checks/         build-time validation (theme lint, config rendering, secrets, password, login shell, Nix lint)
@domains/        features (30 domains / 17 categories) — each with a default.nix interface + optional home.nix/system.nix sides
@lib/            build system, domain framework, host resolution, flake outputs
@modules/        core NixOS/home/VM modules + sops secrets integration
@profiles/       reusable composition units — selected via the host decl's `profiles` list
@scripts/        auxiliary shell scripts (angst CLI, analyze_flake/ analysis generator)
@themes/         color token definitions (9 themes, strict 13-token schema)
@toolchains/     language-domain tooling (23 languages: runtime/LSP/formatter/linter/grammar)
@tools/vm/       standalone Rust workspace for NixOS VM lifecycle (vm-core, vm-cli, vm-mcp)
@tools/shell/    standalone Rust env switcher (dev/safe shells, no nix at runtime)
@githooks/       gitleaks pre-commit / pre-push hooks (install via `just install-hooks`)
```

---

### `@hosts/` — Machine Declarations

Each machine is `hosts/<domain>/<hostname>/default.nix`, a pure data decl. A directory of host directories is a domain (e.g. `personal/` contains `mint/` and `nixos/`). `lib/discover.nix` finds hosts recursively; `lib/resolve.nix` normalizes each decl into a `host` object with defaults (`system`, `hostname`, `username`, `theme = "monochrome"`, `profiles = ["base"]`, `type = "nixos"`, …).

```nix
{
  type = "nixos";                     # "nixos" | "home" (home-only, e.g. mint)
  system = "x86_64-linux";
  hostname = "nixos";
  username = "joao";
  theme = "miasma";
  profiles = ["base" "desktop" "development"];   # validated against profiles/default.nix
  toolchains = "*";                   # all 23 languages, or a list (unknown names throw)
  repoPath = "proj/angst";
  monitors = { primary = { name = "DP-1"; resolution = "1920x1080"; refreshRate = 144; }; };
  db.connections = { };               # sql-client credentials
  nixos = { keyboardLayout = "br-abnt2"; };      # per-machine extras (extraNixos)
  env = { EDITOR = "nvim"; BROWSER = "firefox"; };
  sshAgent = { enable = true; keys = ["~/.ssh/id_ed25519"]; };
  persist = { enable = true; root = "/persist"; homeDirs = [".mozilla" ...]; };  # impermanence
}
```

Optional siblings: `secrets.yaml` (sops-encrypted, see [Secrets](openwiki/secrets.md)) and `hardware.nix` (auto-imported by `mkNixos.nix`). Current hosts: `ci` (CI runner, user `runner`), `personal/nixos` (desktop), `personal/mint` (home-only), `vm` (disposable QEMU VM).

---

### `@domains/` — Feature Declarations

Domains are the single unit of configuration — **30 features across 17 categories** (user apps *and* system features). Each `domains/<category>/<name>/` describes one feature, with optional user (`home.nix`) and system (`system.nix`) sides:

| File | Purpose |
|---|---|
| `default.nix` | **The domain interface**: pure data — `package`, `xdg`/`xdgFile`/`customXdg`, `description`, `mutable`. Validated strictly by `mkDomain` |
| `home.nix` | Optional: custom home-manager module (only when auto-generation isn't enough) |
| `system.nix` | Optional: NixOS module (sshd, i3 WM, `system/*` features) |
| `render.nix` | Optional: theme-aware config generator: `{ themesLib, themeName, ... } → [{ path, text, checks? }]` |
| `config/` | Optional: static config files (symlinked via `xdg.configFile`) |

The domain framework (`lib/domains/`):

- **`mkDomain.nix`** — the interface. Validates each `default.nix` spec: unknown keys, field types, `package` existence in `pkgs`, `xdg`/`xdgFile`/`customXdg` coherence, required `description`, `mutable` basenames, and the conventional side files (`home.nix`/`system.nix`/`render.nix` must be module functions, `config/` a directory). Violations throw `domains/<cat>/<name>/default.nix: <msg>` at eval.
- **`scan.nix`** — recursively discovers domain dirs and runs `mkDomain` over each `default.nix`, producing `entries`/`systemEntries`.
- **`module.nix`** — `mkDomainModule` auto-generates a home-manager module per feature (`enable` option, `home.packages`, `home.file` for rendered outputs, `xdg.configFile` for `config/`, `renderOverrideModule` for `mutable` files); validates the render output contract (`[{ path, text, checks? }]`). `mkNixosSystemModule` imports `system.nix` when present. Each side self-gates on `domains.<cat>.<name>.enable`; `host.type` decides which sides are built (`nixos` → both, `home` → home only).

Full 30-domain inventory: see [openwiki/domains.md](openwiki/domains.md).

Domain categories: `agents/` (opencode, cursor-cli), `bar/` (i3status), `editor/` (nvim), `files/` (yazi), `git/` (lazygit), `http-client/` (posting), `launcher/` (rofi), `nix/` (nh), `remote/` (ssh), `security/` (age, sops), `session/` (x11), `shell/` (nushell, starship, carapace), `sql-client/` (sqlit, rainfrog), `system/` (audio, clipboard, container, git, graphical, monitoring, network, search), `terminal/` (ghostty, zellij, tmux), `wm/` (i3).

Domains are enabled via **profile composition**, not per-host module files.

### `@checks/` — Build-Time Validation

Defined in `checks/` and wired as flake `checks` by `lib/flake/outputs.nix`. Run everything with `nix flake check` (or `nix run .#check`); targeted lints are faster:

| Check | Validates |
|---|---|
| `lint-themes` | All 9 themes load and validate (eval-only, fast) |
| `lint-desktop` | i3 + i3status configs parse per theme |
| `lint-shell` | starship.toml + nushell colors per theme |
| `theme-rendered` | Rendered domain configs contain expected theme tokens |
| `theme-override` | Theme override propagates into a real home config |
| `theme-semantic-distinct` | `ansi.error/warn/info/success` mutually distinct |
| `check-password` | Host `password` field is a valid `$6$` sha-512 hash |
| `check-secrets-encrypted` | Every tracked `secrets.yaml` is sops-encrypted |
| `login-shell-valid` / `login-shell-invalid` | `shellOverride` handling |
| `home-theme-override-test` | Builds a representative home config with an alternate theme |
| `lint-nix` | `deadnix --fail` + `statix check .` |

---

### `@lib/` — Build System, Domain Framework, and Flake Outputs

`lib/` is pure framework — the machinery that makes the flake composable and verifiable:

| Path | Responsibility |
|---|---|
| `lib/discover.nix` | Recursively finds host decls under `hosts/` |
| `lib/resolve.nix` | Normalizes a host decl into a `host` object (defaults, domain/toolchain scanning) |
| `lib/build/mkNixos.nix` | NixOS system constructor (wires profiles, domains, modules, secrets bootstrap, VM detection, hardware) |
| `lib/build/mkHome.nix` | Home-manager profile constructor (domains, toolchains, secrets activation, special args) |
| `lib/domains/` | Domain interface (`mkDomain.nix`) + discovery (`scan.nix`) + module generation (`module.nix`) |
| `lib/flake/outputs.nix` | All flake outputs: home configs, NixOS configs, packages, apps, dev shells, checks, formatter |
| `lib/flake/devshell.nix` | Dev shell definitions (safe, dev, vm) with SSH agent init |
| `lib/render.nix` | Theme rendering engine (`renderDomainOutputsFor`, `renderDomainOutputFor`) |
| `lib/toolchain.nix` | `mkToolchain` builder — translates toolchain attrsets into packages + grammars |
| `lib/treesitter.nix` | Tree-sitter grammar builder for cross-glibc compatibility |
| `lib/nixpkgs-config.nix` | Nixpkgs config (`allowUnfree`) |

---

### `@modules/` — Core Home, NixOS, and VM Modules

**`modules/nixos/`** — Base NixOS config imported by every configuration: `system.stateVersion = "25.11"`, keyboard layout (from `angst.keyboardLayout`, e.g. `br-abnt2`), `America/Sao_Paulo` timezone, `en_US.UTF-8` locale, NetworkManager, flakes + `allowUnfree`, user creation (nushell shell, wheel/networkmanager/video/audio groups), `nix-ld`, fonts, and impermanence (`persist.nix`).

**`modules/home/`** — Base home-manager config: username, stateVersion, fontconfig, tree-sitter (`treesitter.nix`), login shell handling (`login-shell.nix`), secrets activation (`secrets-activation.nix`), theme option (`themeModule.nix`). (SSH client config + agent live in `domains/remote/ssh/`.)

**`modules/vm/`** — Multi-layered VM support: detection (`detect.nix`, `is-qemu-vm.nix` — true when evaluated from a 9p mount), conditional bootloader (`runtime.nix`), vmVariant resources (`vm-variant.nix` — tmpfs `/`, `/persist` ext4, SPICE, 9p host mount), secret/SSH-key injection (`vm-profile.nix`), and host-repo symlink for live editing (`host-mount.nix`). `specialisation.nix` exists but is never imported (dead code).

**`modules/secrets.nix`** — sops-nix integration per host: locates `secrets.yaml`, detects an age key, gates everything behind `canDecrypt`, wires `masterPassword` (system + home) and app secrets (e.g. `opencodeGoKey` → `~/.secrets/opencode-go-key`). See [openwiki/secrets.md](openwiki/secrets.md).

---

### `@profiles/` — Reusable Composition Units

Profiles replace host-specific `home.nix` / `configuration.nix` files. Each is a **pure feature list** — `{ enable = [...]; }` (plus an optional `modules` list for NixOS-only infrastructure). `profiles/default.nix` validates every name at build time (unknown features throw). The builder splits the enabled list into home and system sides based on each feature's `home.nix`/`system.nix` presence and the host `type`. Select via `profiles = [...]` in the host decl.

| Profile | Features (`enable`) |
|---|---|
| `base` | nushell, carapace, starship, zellij, nvim, yazi, lazygit, nh, age, sops, network, git, search, monitoring, container, **ssh** |
| `desktop` | rofi, ghostty, x11, graphical, audio, clipboard |
| `development` | opencode, cursor-cli, sqlit, rainfrog, posting |
| `server` | ssh (sshd is driven per-host via `host.ssh.server.enable`) |
| `vm` | ssh + VM modules (detect, runtime, variant, profile, host-mount) |

> Note: `wm/i3` and `bar/i3status` exist as domains but are currently **commented out** in `profiles/desktop.nix`.

---

### `@themes/` — Color Token Definitions

9 themes, each a compact Nix attrset with 13 tokens (**9 palette + 4 ansi**): `background`, `surface`, `foreground`, `accent` (each `{ base, variant }`), `dim`, and `ansi.error/warn/info/success`. Available: `catppuccin-mocha`, `github`, `gotham`, `kanagawa`, `lotus`, `miasma`, `monochrome` (default), `noctis`, `rose-pine`.

`themes/default.nix` normalizes (strips `#`, validates hex), enriches with RGB variants (`_RGB`) for apps that need integer colors, and provides contrast-checked `safe.*` tokens. Themes resolve at eval time via `themesLib.get "<name>"` and are rendered into every domain config. See [openwiki/themes.md](openwiki/themes.md).

---

### `@toolchains/` — Language-Domain Tooling

23 language toolchains defined via `mkToolchain` (`lib/toolchain.nix`), each providing runtime, LSP, formatter, linter, tools, and tree-sitter grammar entries.

Supported: `bash`, `blade`, `c`, `clojure`, `conf`, `css`, `docker`, `go`, `html`, `java`, `javascript`, `json`, `just`, `lua`, `markdown`, `nix`, `php`, `python`, `rust`, `terraform`, `toml`, `xml`, `yaml`.

Toolchains are auto-discovered by `lib/resolve.nix` and selected via `toolchains = "*"` or a validated list in the host decl. Packages flow into home-manager and dev shells; grammars flow into tree-sitter setup via `lib/treesitter.nix`.

---

### `@tools/` — Standalone Tools

**angst CLI** (`scripts/angst.sh`, packaged as `angst`):
- `angst bootstrap-secrets [--host HOST]` — interactive master-password bootstrap (sops + mkpasswd); writes `secrets.yaml` and the sha-512 hash into the host decl.
- `angst render [--repo PATH] [--host HOST] [--theme THEME] [--reload|--no-reload]` — batch-evals `.#lib.renderDomainOutputsFor` and writes rendered domain configs.
- `angst watch [...]` — watchexec-based hot-reload on `themes/`, `domains/`, `hosts/`.

**shell CLI** (`tools/shell`, Rust) — standalone env switcher (no nix at runtime): `nix run .#shell -- dev` or `shell safe` after `nix profile install .#shell`.

**vm tool** (`tools/vm`, Rust workspace: `vm-core`, `vm-cli`, `vm-mcp`) — QEMU VM lifecycle with SSH (port 2222 → guest 22), headless mode for CI, automatic SSH key + age key injection, and an MCP server (port 8765, tools `vm_exec`/`vm_status`/`vm_restart`) for AI agent integration.

Commands: `start [--headless]`, `stop`, `restart`, `status`, `logs [-n]`, `ssh [--auto-start] [--tty]`, `exec -- <cmd>`, `copy-to`, `copy-from`, `health`, `mcp {start|stop|restart|status|logs|run-server [--port]}`.

```bash
nix run .#vm -- --headless          # or: just vm; DISPLAY set → gtk UI
nix run .#vm -- ssh                 # connect
nix run .#vm -- health              # QEMU + port + SSH check
```

See [openwiki/tools.md](openwiki/tools.md) and [openwiki/operations.md](openwiki/operations.md).

---

### Data Flow

```
hosts/<domain>/<host>/default.nix         # pure data: theme, user, profiles, toolchains
       │
       ▼
lib/discover.nix → lib/resolve.nix        # find decls, normalize into host objects
       │
       ▼
lib/build/mkNixos.nix / mkHome.nix        # NixOS system + home-manager profile builders
       │
       ▼
domains/<cat>/<name>/render.nix           # each domain: theme tokens → [{ path, text }]
       │
       ▼
angst render                               # writes rendered files into the repo
       │
       ▼
home-manager activation                    # xdg.configFile symlinks → ~/.config/<app>
```

### Secrets (summary)

Per-host `secrets.yaml` (sops + age) → decrypted at runtime into `~/.secrets/`. The `masterPassword` secret drives login-hash and SSH-key bootstrap (`angst-bootstrap-secrets` systemd service + home activation). The VM receives the host's age key + SSH keys via a shared dir at boot — keys are never baked into the image. Defense in depth: gitleaks pre-commit/pre-push hooks, gitleaks + trufflehog CI, and a flake check that refuses unencrypted `secrets.yaml`. Full story: [openwiki/secrets.md](openwiki/secrets.md).

### CI

`.github/workflows/`:

| Workflow | Runs |
|---|---|
| `checks.yml` | Per-check `nix build '.#checks.x86_64-linux.<name>'` jobs for the 10 flake checks + nixfmt + shellfmt + `shell-rust-fmt` + `vm-tests` (`cargo fmt --check && cargo test --workspace --locked`) |
| `nvim-tests.yml` | Links `domains/editor/nvim/config` → `~/.config/nvim`, lazy-syncs plugins, runs the plenary adapter test suite |
| `secret-scan.yml` | gitleaks-action (fetch-depth 0) + trufflehog (`--results=verified,unknown`) |
| `openwiki-update.yml` | Daily cron + manual: runs `openwiki code --update --print`, opens a PR with `openwiki/` + agent doc changes |

Nix CI uses DeterminateSystems `nix-installer-action` + `magic-nix-cache-action`.

### Useful Commands

```bash
just check                 # nix flake check
just hm host=nixos user=joao        # build home activation package
just hm-switch host=nixos user=joao # build + activate
just switch host=nixos              # sudo nixos-rebuild switch --flake .#nixos
just hardware host=nixos            # regenerate hardware.nix next to the decl
just bootstrap-secrets host=nixos   # create/rotate secrets.yaml + password hash
just analyze                        # regenerate analysis.md
just install-hooks                  # enable gitleaks git hooks
just vm host=vm / just vm-ssh host=vm   # VM start / ssh via tools/vm#wrapped
```
