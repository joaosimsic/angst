# angst

NixOS + home-manager flake for a theme-driven, hot-reloadable desktop environment.

Every machine is declared as a plain, diffable Nix file under `hosts/` and auto-discovered at flake eval time — no `flake.nix` edits, no env-file hacks. Secrets are age-encrypted (`secrets/master/<host>.age` for the login password, `secrets/apps/<scope>/<slug>.age` for app secrets) and decrypted at runtime. A single color-theme system propagates across ~21 user-space applications.

Maintained reference documentation lives in [openwiki/](openwiki/quickstart.md) (quickstart, [architecture](openwiki/architecture.md), [domains](openwiki/domains.md), [themes](openwiki/themes.md), [tools](openwiki/tools.md), [operations](openwiki/operations.md), [secrets](openwiki/secrets.md)).

## Quick Start

```bash
# Build + switch a NixOS host (hostname comes from hosts/<domain>/<hostname>/default.nix)
nixos-rebuild switch --flake .#nixos

# Home-manager only (also for type = "home" hosts like mint)
just hm-switch host=nixos            # or: nix build .#homeConfigurations.joao.activationPackage && ./result/activate

# Development shells
nix develop .#safe                   # editing env: neovim, parsers, LSPs, formatters
nix develop .#dev                    # full env: angst CLI, qemu, age, gitleaks, Rust, VM tools
nix develop .#vm                     # QEMU VM (Go angst tooling)

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
@checks/         build-time validation (theme lint, config rendering, secrets, projects, password, login shell, Nix lint)
@domains/        features (31 domains / 17 categories) — each with a default.nix interface + optional home.nix/system.nix sides
@projects/       encrypted, auto-synced dev-project store (age-encrypted tarballs; simple slug ids, real name only in encrypted metadata)
@lib/            build system, domain framework, host resolution, flake outputs
@modules/        core NixOS/home/VM modules + age secrets integration
@profiles/       reusable composition units — selected via the host decl's `profiles` list
@runtime/        runtime tooling as Nix functions + Go CLIs (angst, vm, angst-shell, analyze)
@themes/         color token definitions (9 themes, strict 13-token schema)
@toolchains/     language-domain tooling (24 languages: runtime/LSP/formatter/linter/grammar)
@runtime/angst/  Go CLI `angst` (render, watch, projects, vault, ftp, ssh-key, system, boot) — core host orchestration
@runtime/vm/     Go CLI `vm` (unified guest+host + MCP) — QEMU VM lifecycle; guest scripts in `runtime/vm/*.nix`
@runtime/shell/  Go CLI `angst-shell` (dev|safe env switcher)
@runtime/analyze/ Go CLI `analyze` (flake analysis report → analysis.md)
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
  toolchains = "*";                   # all 24 languages, or a list (unknown names throw)
  monitors = { primary = { name = "DP-1"; resolution = "1920x1080"; refreshRate = 144; }; };
  db.connections = { };               # sql-client credentials
  nixos = { keyboardLayout = "br-abnt2"; };      # per-machine extras (extraNixos)
  env = { EDITOR = "nvim"; BROWSER = "firefox"; };
  sshAgent = { enable = true; keys = ["~/.ssh/id_ed25519"]; };
  persist = { enable = true; root = "/persist"; homeDirs = [".mozilla" ...]; };  # impermanence
}
```

Optional siblings: `secrets/master/<host>.age` and `secrets/apps/` (age-encrypted, see [Secrets](openwiki/secrets.md)) and `hardware.nix` (auto-imported by `mkNixos.nix`). Current hosts: `ci` (CI runner, user `runner`), `personal/nixos` (desktop), `personal/mint` (home-only), `vm` (disposable QEMU VM).

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

Full 31-domain inventory: see [openwiki/domains.md](openwiki/domains.md).

Domain categories: `agents/` (opencode, cursor-cli), `bar/` (i3status), `editor/` (nvim), `files/` (yazi), `git/` (lazygit, projects), `http-client/` (posting), `launcher/` (rofi), `nix/` (nh),   `remote/` (ssh), `security/` (age), `session/` (x11), `shell/` (nushell, starship, carapace), `sql-client/` (sqlit, rainfrog), `system/` (audio, clipboard, container, git, graphical, monitoring, network, search), `terminal/` (ghostty, zellij, tmux), `wm/` (i3).

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
| `check-secrets-encrypted` | Every `secrets/master/*.age` is age-encrypted |
| `check-secrets-encrypted` | Every `secrets/master/*.age` is age-encrypted |
| `login-shell-valid` / `login-shell-invalid` | `shellOverride` handling |
| `home-theme-override-test` | Builds a representative home config with an alternate theme |
| `lint-nix` | `deadnix --fail` + `statix check .` |

---

### `@projects/` — Auto-Synced Encrypted Dev Projects

`domains/git/projects` + the `angst projects` subcommand of the Go `angst` binary (`runtime/angst`, shared by the CLI and the `angst-projects-sync` wrapper) give every host the same set of dev
repositories with working `.env` files — while the angst repo stays **public** and reveals
nothing about them.

Two layers, with the repo store as committed, age-encrypted tarballs:

- **Repo store** — `projects/{personal,work}.tar.age` (committed, **age-encrypted**). Each
  tarball holds the whole `<scope>/<id>/{metadata.json,.env}` tree. This is the transport:
  it travels with the public repo, so a new machine that clones the repo has all the
  metadata to clone its projects. Rewritten only by your manual `vault` edit flow (below).
- **Working store** — `~/.secrets/projects/{personal,work}/<id>/{metadata.json,.env}` (fixed
  per-host, **decrypted plaintext**). `sync` reads this directly — no age needed at runtime.
  Seeded from the tarballs at build time (home activation runs `import`).
- **Clone root** — `~/projects/<name>`: the cloned repo + its decrypted `.env`. Clones
  **diverge per host** (each host selects by slug; `sync` only clone-if-missing).

- **Scope-isolated tarballs** — `personal.tar.age` is encrypted only with the personal age
  recipient, `work.tar.age` only with the work recipient, so a work-key compromise can't
  decrypt personal projects. Personal = `~/.config/age/keys.txt`; work =
  `~/.config/age/work-keys.txt` (static, provisioned out-of-band). The recipient is
  derived from the scope key file at encrypt/decrypt time.
- **Hosts declare *which* projects, by slug** — each host decl sets
  `projects = [ "<slug>" ... ]`; slugs may be nested paths (e.g. `intelligence/backend`), in which case
  the id is the relative path under the scope (the store is discovered recursively). The real name
  never appears in tracked files (it lives only in the encrypted `metadata.json`). Empty list =
  nothing synced. Works on NixOS **and** home-only hosts (`nixos`/`home` host types).
  `~/projects` is only persisted when the host declared at least one project.
- **Clone if missing only** — `sync` (home activation + `systemd.user` oneshot
  `angst-projects-sync`) clones the host's selected projects into `~/projects/<name>`
  when the dir has no `.git`; no auto-pull, no hooks, no `.gitignore` edits — clones are
  never modified for leak prevention. The only file written into a clone is the
  decrypted `.env` (0600).
- **Env handling** — working-store `.env` is materialized/refreshed hash-tracked via a
  sidecar (`~/.secrets/projects/<name>.env.sha256`). A locally-edited `.env` is **never
  clobbered**: `sync` marks it `stale`, prints a redacted key-name-only diff, and exits
  non-zero.
- **Resilient** — missing key, missing tarball, no network, or a decrypt error skips that
  project with a warning and exits 0; nothing fails a build or boot.
- **Leak prevention (defense in depth)** — the repo store is always age-encrypted
  (`check-projects-encrypted` + gitleaks guard it); plaintext lives only in the private
  `~/.secrets` working store (0700) and in the decrypted `.env` files.

```bash
# Runtime (on a host):
angst projects import   # decrypt projects/*.tar.age -> working store
angst projects sync     # clone-if-missing + env materialize (working store)

# Editing the repo store (run from the repo root, then commit the .tar.age):
angst vault decrypt projects/personal.tar.age --dir --scope personal   # -> projects/personal/
# ... edit projects/personal/<id>/metadata.json and/or .env by hand ...
angst vault encrypt projects/personal --dir --scope personal           # overwrites projects/personal.tar.age, removes projects/personal/
git add projects/personal.tar.age && git commit
```

The decrypted scope dirs (`projects/personal/`, `projects/work/`) are gitignored, so an
in-place decrypt never stages plaintext. All secrets are age-encrypted, so no sops tooling is required.

---

### `@lib/` — Build System, Domain Framework, and Flake Outputs

`lib/` is pure framework — the machinery that makes the flake composable and verifiable:

| Path | Responsibility |
|---|---|
| `lib/discover.nix` | Recursively finds host decls under `hosts/` |
| `lib/resolve.nix` | Normalizes a host decl into a `host` object (defaults, domain/toolchain scanning) |
| `lib/build/mkNixos.nix` | NixOS system constructor (wires profiles, domains, modules, secrets bootstrap, VM stack, hardware) |
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

**`modules/vm/`** — Multi-layered VM support: internal `angst.isQemuVm` flag (declared — forced on by the `vm` profile and by `vmVariant`, never probed at eval time), conditional bootloader (`runtime.nix`), vmVariant resources (`vm-variant.nix` — tmpfs `/`, `/persist` ext4, SPICE, 9p host mount), declarative inbound auth + age-key injection (`vm-profile.nix` — `authorized_keys` baked from `secrets/ssh/*.pub`, `vm-age-key` consumes `/tmp/shared`), and host-repo symlink for live editing (`host-mount.nix`). `specialisation.nix` exists but is never imported (dead code).

**`modules/secrets.nix`** — age secrets integration per host: the master password (`secrets/master/<host>.age`, decrypted by `angst set-password-hash` at boot) and app secrets (e.g. `opencode-go-key` → `~/.secrets/opencode-go-key`, provisioned by `angst provision-app-secret`). Decryption is decided at runtime (age key at `~/.config/age/keys.txt`), never at eval — pure-`nix build` hosts like the VM still get secret wiring. See [openwiki/secrets.md](openwiki/secrets.md).

---

### `@profiles/` — Reusable Composition Units

Profiles replace host-specific `home.nix` / `configuration.nix` files. Each is a **pure feature list** — `{ enable = [...]; }` (plus an optional `modules` list for NixOS-only infrastructure). `profiles/default.nix` validates every name at build time (unknown features throw). The builder splits the enabled list into home and system sides based on each feature's `home.nix`/`system.nix` presence and the host `type`. Select via `profiles = [...]` in the host decl.

| Profile | Features (`enable`) |
|---|---|
| `base` | nushell, carapace, starship, zellij, nvim, yazi, lazygit, nh, age, network, git, search, monitoring, container, **ssh** |
| `desktop` | rofi, ghostty, x11, graphical, audio, clipboard |
| `development` | opencode, cursor-cli, sqlit, rainfrog, posting, **git.projects** |
| `server` | ssh (sshd is driven per-host via `host.ssh.server.enable`) |
| `vm` | ssh + VM modules (runtime, variant, profile, host-mount) |

> Note: `wm/i3` and `bar/i3status` exist as domains but are currently **commented out** in `profiles/desktop.nix`.

---

### `@themes/` — Color Token Definitions

9 themes, each a compact Nix attrset with 13 tokens (**9 palette + 4 ansi**): `background`, `surface`, `foreground`, `accent` (each `{ base, variant }`), `dim`, and `ansi.error/warn/info/success`. Available: `catppuccin-mocha`, `github`, `gotham`, `kanagawa`, `lotus`, `miasma`, `monochrome` (default), `noctis`, `rose-pine`.

`themes/default.nix` normalizes (strips `#`, validates hex), enriches with RGB variants (`_RGB`) for apps that need integer colors, and provides contrast-checked `safe.*` tokens. Themes resolve at eval time via `themesLib.get "<name>"` and are rendered into every domain config. See [openwiki/themes.md](openwiki/themes.md).

---

### `@toolchains/` — Language-Domain Tooling

24 language toolchains defined via `mkToolchain` (`lib/toolchain.nix`), each providing runtime, LSP, formatter, linter, tools, and tree-sitter grammar entries.

Supported: `bash`, `blade`, `c`, `clojure`, `conf`, `css`, `docker`, `go`, `html`, `java`, `javascript`, `json`, `just`, `lua`, `markdown`, `nix`, `php`, `python`, `rust`, `terraform`, `toml`, `xml`, `yaml`.

Toolchains are auto-discovered by `lib/resolve.nix` and selected via `toolchains = "*"` or a validated list in the host decl. Packages flow into home-manager and dev shells; grammars flow into tree-sitter setup via `lib/treesitter.nix`.

---

### `@tools/` — Standalone Tools

**angst CLI** (`runtime/angst`, packaged as `angst`):
- `angst bootstrap-master-password [--host HOST] [--scope personal|work]` — interactive master-password bootstrap; age-encrypts the password to `secrets/master/<host>.age`. The boot service derives the sha-512 hash.
- `angst render [--repo PATH] [--host HOST] [--theme THEME] [--reload|--no-reload]` — batch-evals `.#lib.renderDomainOutputsFor` and writes rendered domain configs.
- `angst watch [...]` — watchexec-based hot-reload on `themes/`, `domains/`, `hosts/`.
- `angst projects <add|sync|status|capture|edit-env|rm> ...` — manage the encrypted dev-project store (see [`@projects/`](#projects--auto-synced-encrypted-dev-projects)).
- `angst ssh-key <generate|verify> --scope personal|work` — generate/verify the shared, age-encrypted scope SSH keys in `secrets/ssh/` (see [`@secrets/`](#secrets-summary)).

**vm CLI** (`runtime/vm`, packaged as `vm` / `vm-tool`) — QEMU VM lifecycle with SSH (port 2222 → guest 22), headless mode for CI, automatic SSH key + age key injection, and an MCP server (port 8765, tools `vm_exec`/`vm_status`/`vm_restart`) for AI agent integration. Guest-side helpers (`age-key`, `ephemeral-ssh`, `home-manager-upgrade`, `nixos-switch`, `home-switch`) are `vm` subcommands (`runtime/vm/*.nix` wrappers).

Commands: `start [--headless]`, `stop`, `restart`, `status`, `logs [-n]`, `ssh [--auto-start] [--tty]`, `exec -- <cmd>`, `copy-to`, `copy-from`, `health`, `mcp {start|stop|restart|status|logs|run-server [--port]}`.

```bash
nix run .#vm -- start --headless    # or: just vm; DISPLAY set → gtk UI
nix run .#vm -- ssh                 # connect
nix run .#vm -- health              # QEMU + port + SSH check
```

**shell CLI** (`runtime/shell`, packaged as `angst-shell`) — env switcher (`angst-shell dev|safe`) with tree-sitter setup; Nix wrapper supplies `SHELL_*` env and `PATH`.

**analyze CLI** (`runtime/analyze`, packaged as `analyze`) — flake analysis report (`nix run .#analyze -- --output analysis.md`).

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

age-encrypted secrets → decrypted at runtime into `~/.secrets/`. The master password (`secrets/master/<host>.age`) drives the login-hash via the `angst-bootstrap-secrets` systemd service; app secrets (e.g. `opencode-go-key`) land at `~/.secrets/` via `angst provision-app-secret`. Shared scope SSH keys are age-encrypted in `secrets/ssh/` and provisioned to every host at boot by `angst-provision-ssh-key`; the FTP server config lives age-encrypted in `secrets/ftp/`. The VM receives the host's age key + SSH keys via a shared dir at boot — keys are never baked into the image. The `projects/` store is age-encrypted (vault tarballs) too, with scope-isolated keys (repo tarballs travel; working store decrypted at `~/.secrets/projects`, see [`@projects/`](#projects--auto-synced-encrypted-dev-projects)). Defense in depth: gitleaks pre-commit/pre-push hooks, gitleaks + trufflehog CI, and flake checks that refuse unencrypted `secrets/master/*.age` / non-encrypted `projects/*.tar.age` / `secrets/ssh/*.age` / `secrets/ftp/*`. Full story: [openwiki/secrets.md](openwiki/secrets.md).

### CI

`.github/workflows/`:

| Workflow | Runs |
|---|---|
| `checks.yml` | Per-check `nix build '.#checks.x86_64-linux.<name>'` jobs for the flake checks + nixfmt + shellfmt + Go (`gofmt`/`go vet`/`go test` across `runtime/{angst,vm,shell,analyze}`) |
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
just vm host=vm / just vm-ssh host=vm   # VM start / ssh via vm CLI
```
