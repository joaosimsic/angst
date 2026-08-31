# Domains

Domains (features) are the **unit of configuration** in angst. Each domain describes one feature — a user application, a system feature, or both. There are currently **38 domains across 20 categories**.

## Domain Anatomy

```
domains/<category>/<name>/
├── default.nix    # Required: the domain interface (pure data) — validated by mkDomain
├── home.nix       # Optional: custom home-manager module (only when auto-gen isn't enough)
├── system.nix     # Optional: NixOS module (system features, sshd, i3 WM)
├── render.nix     # Optional: theme-aware config generator
└── config/        # Optional: static config files (symlinked via xdg.configFile)
```

### default.nix (the interface)

Pure data declaring the domain's characteristics. `mkDomain` (`lib/domains/mkDomain.nix`) validates it strictly and **throws** on violation:

- **unknown attributes** (typos) → throw listing valid fields;
- `package` must be a non-empty string **that exists in `pkgs`**;
- `xdg`/`xdgFile` relative paths, mutually exclusive; `customXdg` bool;
- `description` required (non-empty);
- `mutable` list of basenames (requires `render.nix`);
- **conventional side files** are validated too: `home.nix`/`system.nix`/`render.nix` must be module functions, `config/` a directory; `customXdg = true` requires `home.nix`; render/config require a placement target; an empty domain throws.

```nix
{ package = "zellij"; xdg = "zellij"; description = "Terminal multiplexer"; }
```

### render.nix

The heart of the theme system: a function taking `{ themesLib, themeName, homeDirectory, ... }` (see `lib/render.nix`, `renderDomainOutputsFor`) and returning `[{ path, text, checks? }]`. `path` is repo-relative (`domains/<cat>/<name>/config/…`); the framework maps it to the correct XDG location and validates the output shape (`path`/`text` strings, `checks` a list, unique paths). Rendered outputs can carry `checks` (e.g. "this ghostty color must equal `palette 5`") that the theme checks assert.

## Framework (`lib/domains/`)

- **`mkDomain.nix`** — the interface: validates a `default.nix` spec (characteristics + conventional side files) and returns the normalized entry.
- **`scan.nix`** — `readDir` over `/domains/` → category → name, imports each `default.nix`, runs it through `mkDomain`, and produces `entries` + `systemEntries` (features with a `system.nix`). Exposed to every builder via `host.scan.domains`.
- **`module.nix`** — `mkDomainModule` auto-generates a home-manager module per feature:
  - `baseModule`: `domains.<cat>.<name>.enable` option, `home.packages` from `meta.package`, `home.file` for rendered outputs;
  - `configSourceModule`: recursive walk of `config/` → `xdg.configFile` symlinks (skipping `.gitignore`, `node_modules`, and `meta.mutable` files);
  - `renderOverrideModule`: filters rendered files by `mutable`;
  - plus the feature's custom `home.nix` if present.
  - `mkNixosSystemModule` imports `system.nix` when present (each system side self-gates on its own `domains.<cat>.<name>.enable`; `host.type` decides whether system sides are built at all).

There is **no** `lib/domains/activation.nix` (README is stale); activation happens through home-manager `xdg.configFile` and, in VMs, `modules/vm/host-mount.nix` gives live access to the host repo.

## Domain Inventory (38)

| Category | Name | Package | XDG | Render | home | system | Purpose |
|---|---|---|---|---|---|---|---|
| agents | cursor-cli | cursor-cli | custom | — | ✅ | — | Cursor AI CLI (package-only) |
| agents | opencode | opencode | opencode | ✅ | ✅ | — | AI coding agent: 22 LSPs, themed TUI, API key from age-encrypted app secret |
| bar | i3status | *(none)* | i3status | ✅ | ✅ | — | i3 status bar (themed blocks) |
| browser | firefox | *(none)* | custom | — | ✅ | ✅ | Firefox (policies + tridactyl, themed) |
| capture | screenshot | *(none)* | custom | — | ✅ | ✅ | Screen capture via portal/maim/grim + `angst-screenshot` |
| display | lightdm | *(none)* | — | — | — | ✅ | LightDM GTK greeter |
| display | ly | *(none)* | — | — | — | ✅ | ly TUI display manager |
| display | x11 | *(none)* | custom | — | ✅ | ✅ | X11 session autostart |
| editor | nvim | *(none)* | nvim | ✅ | ✅ | — | Neovim: backend adapters/engines, treesitter, Lua tests |
| embedded | arduino | arduino-cli | custom | — | ✅ | ✅ | Arduino CLI |
| files | yazi | *(none)* | yazi | ✅ | ✅ | — | Terminal file manager |
| git | code | git | — | — | — | ✅ | Git version control (system) |
| git | lazygit | lazygit | lazygit | ✅ | ✅ | — | Git TUI |
| git | projects | *(none)* | custom | — | ✅ | — | Auto-synced encrypted dev projects (clone + `.env` via vault/age tarballs) |
| http-client | posting | posting | posting | ✅ | ✅ | — | Terminal HTTP client |
| kernel | audio | *(none)* | — | — | — | ✅ | PipeWire with ALSA/PulseAudio compat |
| kernel | clipboard | *(none)* | — | — | — | ✅ | xclip + xsel |
| kernel | container | *(none)* | — | — | — | ✅ | Docker + Podman, kubectl, lazydocker |
| kernel | cursor | *(none)* | custom | — | ✅ | — | Cursor theme (X11/GTK) |
| kernel | graphical | *(none)* | — | — | — | ✅ | X11, LightDM (themed), libinput, dbus, XDG portals |
| kernel | monitoring | *(none)* | — | — | — | ✅ | btop |
| kernel | network | *(none)* | — | — | — | ✅ | wget, curl, unzip |
| kernel | search | *(none)* | — | — | — | ✅ | fd, ripgrep, fzf |
| launcher | rofi | rofi | rofi | ✅ | ✅ | — | App launcher |
| nix | nh | nh | — | — | — | — | Nix CLI helper (package-only) |
| notifications | notifications | *(none)* | custom | — | ✅ | ✅ | Notification daemon (dunst/mako, `angst-notify`) |
| remote | ftp | rclone | custom | — | ✅ | ✅ | FTP rclone mount (vault/age) |
| remote | ssh | openssh | custom | — | ✅ | ✅ | SSH client+agent (home) and sshd (system, per-host opt-in) |
| security | age | age | — | — | — | — | age encryption (package-only) |
| shell | carapace | carapace | custom | — | ✅ | — | Shell completion engine |
| shell | nushell | nushell | nushell | ✅ | ✅ | — | Nushell config (themed) |
| shell | starship | starship | `starship.toml` (xdgFile) | ✅ | ✅ | — | Prompt (themed) |
| sql-client | rainfrog | rainfrog | rainfrog | ✅ | ✅ | — | TUI DB manager |
| sql-client | sqlit | sqlit-tui | sqlit | ✅ | ✅ | — | TUI SQL browser |
| terminal | ghostty | ghostty | ghostty | ✅ | ✅ | — | GPU terminal (themed) |
| terminal | tmux | tmux | `tmux/tmux.conf` (xdgFile) | ✅ | ✅ | — | Terminal multiplexer |
| terminal | zellij | zellij | zellij | ✅ | ✅ | — | Multiplexer (layout.nix + theme.nix) |
| wm | i3 | *(none)* | i3 | ✅ | ✅ | ✅ | i3 WM: themed config (home) + `services.xserver.windowManager.i3` (system) |

Note: the `home`/`system` columns mark which optional sides a feature ships. Domains with `*(none)*` package rely on their module or system side for installation. `host.type` decides which sides are built — `nixos` hosts build both, `home`-only hosts (e.g. mint) build only home sides.

## Notable Domains

### `agents/opencode`

The most complex domain. `home.nix` + `config/opencode.jsonc` wire the opencode agent with **22 LSP servers** (nixd, lua-ls, rust-analyzer, gopls, pyright, ts/js, html/css/json, yaml, bash, marksman, jdtls, phpactor, docker, terraform-ls, clojure-lsp, lemminx, clangd, vue, taplo; intelephense disabled). The provider API key comes from an age-encrypted app secret via `{file:~/.secrets/opencode-go-key}` (see [Secrets](secrets.md)). `render.nix` emits a themed `tui.json` + `themes/angst.json`. Git history: `50e80de` added the API key, `84b7ab8` fixed decryption, `e117d52` added LSPs, `b622a81` enabled the experimental feature.

### `editor/nvim`

A Lua config with a pluggable backend (`config/lua/backend/`):
- `adapters/*.lua` — 28 per-language definitions `{filetypes, lsp, lsp_cmd, formatter, treesitter}` (e.g. `json.lua`);
- `engines/` — completion/formatter/linter/lsp/treesitter drivers; `engines/treesitter.lua` registers grammar mappings (sh→bash, jsonc→json…), augroups, and prepends `~/.local/share/tree-sitter(-fixed)` to rtp;
- `shared/` — AdapterLoader/Scanner/Tool, LspTool; `frontend/`, `common/`, `config/` (themed `palette.lua`), `infra/`, `queries/`.
- Tests live in `config/tests/` (`run.sh` → `bootstrap.lua` → plenary suite at `tests/adapters/suite.lua`: loader_scanner, lsp_settings, inlay_hints, engine_mappings, startup). CI runs them via `.github/workflows/nvim-tests.yml`. Recent fixes: `be87346` jsonc→json treesitter mapping; `163d922` re-apply highlight on reopen.

### `git/projects` — encrypted project store (tarball + vault/age)

`home.nix` builds an `angst-projects-sync` wrapper (`pkgs.writeShellApplication`) from the shared `runtime/projects-sync.nix` logic (runtime inputs: git, age, openssh). It runs `import` then `sync` as a home activation entry and as a `systemd.user` oneshot (`angst-projects-sync`, `After`/`Wants network-online.target`).

Layers:

- **Repo store** — `projects/{personal,work}.tar.age` (committed, **age-encrypted**). Each
  tarball holds the whole `<scope>/<id>/{metadata.json,.env}` tree. The transport: travels
  with the public repo so a new machine has the metadata to clone its projects. Rewritten
  only by the manual `vault` edit flow (`angst vault decrypt --dir` → edit → `angst vault
  encrypt --dir`, then commit the `.tar.age`).
- **Working store** — `~/.secrets/projects/{personal,work}/<id>/{metadata.json,.env}` (fixed
  per-host, **decrypted plaintext**). Runtime ops read this directly (no age at runtime).
  Seeded from the tarballs at build time via `import`.
- **Clone root** — `~/projects/<name>`: cloned repo + decrypted `.env`, divergent per host.

Each project is a folder `<slug>/` inside the scope tarball, where `<slug>` is any identifier you choose — including nested paths (e.g. `dotfiles`, `website`, or `intelligence/backend`); the store is discovered recursively, so a project may live at any depth under the scope and its id is the relative path (e.g. `intelligence/backend`). Real names/URLs exist only in the encrypted tarball (in `metadata.json`). Scope is the tarball path; `personal` and `work` use different age keys (a `work.tar.age` never lists the personal recipient). The per-scope recipient is derived from the scope key file at encrypt/decrypt time (no repo `.sops.yaml` routing — the old `projects/{personal,work}/.*` sops rules are gone).

Hosts declare **which** projects they want as a list of slugs
(`projects = [ "<slug>" ... ]` in the host decl, using the nested relative path for grouped projects like `intelligence/backend`). The real name never appears in tracked files (it lives only in the encrypted `metadata.json`); an empty list
syncs nothing. The wrapper bakes the list into `ANGST_PROJECTS_ONLY`; the same domain module
works on `nixos` and home-only hosts (a `projects` specialArg is threaded through both
builders).

Per-registry-project sync: `mkdir -p ~/projects` (0755) → clone-if-missing into `~/projects/<name>` (no auto-pull, no hooks, no `.gitignore` edits — clones are never modified) → `.env` materialized/refreshed hash-tracked via `~/.secrets/projects/<name>.env.sha256`. A locally-edited `.env` is never clobbered: `sync` marks it `stale` and prints a redacted (key-name-only) diff, exiting non-zero. Missing keys/tarballs, no network, or decrypt errors skip with a warning and exit 0 — nothing fails a build or boot. The repo store only changes via the `vault` edit flow (then commit). See [Secrets — Project store](secrets.md#project-store) for the age/key flow.

### `wm/i3`

One of two features with a `system.nix` (alongside `remote/ssh`): `system.nix` enables `services.xserver.windowManager.i3` (asserting `system.graphical`), while the themed i3 config ships via `config/` + `render.nix`. Note `profiles/desktop.nix` currently has i3/i3status **commented out** (the desktop profile enables rofi/ghostty/x11).

## Toolchains (`/toolchains/`)

24 language toolchains (+ `toolchains/default.nix` aggregator): bash, blade, c, clojure, conf, css, docker, go, haskell, html, java, javascript, json, just, lua, markdown, nix, php, python, rust, terraform, toml, xml, yaml.

Each file calls `mkToolchain` (`lib/toolchain.nix`) with `{ runtime, lsp, formatter, linter, tools, packageManager, treesitter }`; the builder unions them into `home.packages` and collects `treesitterGrammars`. Examples: `rust.nix` (rustc/cargo + rust-analyzer + clippy/rustfmt + tree-sitter-rust); `nix.nix` (nil+nixd, nixfmt, statix+deadnix, nix-output-monitor+nix-tree); `javascript.nix` (nodejs+bun, 5 LSPs incl. vue/angular/prisma, prettierd, eslint_d).

`lib/treesitter.nix` builds cross-glibc parsers: copies each grammar `parser` → `<lang>.so` with `patchelf --set-rpath`, and copies `queries/` dirs; `lang` = pname minus `tree-sitter-`, `-` → `_`. Selected via `host.toolchains` in the host decl (`"*"` or a validated list — unknown names throw at eval).

## Change Guidance

- **Add a domain**: create the dir + `default.nix` (the interface), optionally `home.nix` (user side) / `system.nix` (system side), `render.nix`, `config/`. Enable via a profile (`"category.name"` in `profiles/<name>.nix`'s `enable` list). Rendered outputs follow from `render.nix`; static files from `config/`.
- **System-only features**: ship a `system.nix` and omit the XDG target from `default.nix` (e.g. `system/*`). They only apply on `nixos` hosts.
- **Cross-cutting features** (e.g. `remote/ssh`): put the user side in `home.nix` and the system side in `system.nix`; enable the feature once and the builder routes it by host type.
- **The `mutable` meta flag** excludes files from render-override, useful for user-local state inside a config dir.
- **Keep `default.nix` valid** — `mkDomain` throws on interface violations (unknown keys, bad types, incoherent XDG/package/home combos, malformed side files), and any host build fails.
- **nvim changes** should keep `config/tests/` green (`bash tests/run.sh` or CI nvim-tests); treesitter grammar mapping lives in `engines/treesitter.lua`.
- **Toolchain changes** flow into dev shells and home packages automatically once the file exists; verify with `nix eval .#nixosConfigurations.ci.config.home-manager.users.runner.packages` (ci host uses `toolchains = ["nix"]`) or a full build.
