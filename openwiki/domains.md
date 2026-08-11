# Domains

Domains (features) are the **unit of configuration** in angst. Each domain describes one feature — a user application, a system feature, or both. There are currently **27 domains across 17 categories**.

## Domain Anatomy

```
domains/<category>/<name>/
├── meta.nix       # Required: package name, XDG target, description
├── home.nix       # Optional: custom home-manager module (only when auto-gen isn't enough)
├── system.nix     # Optional: NixOS module (system features, sshd, i3 WM)
├── render.nix     # Optional: theme-aware config generator
└── config/        # Optional: static config files (symlinked via xdg.configFile)
```

### meta.nix

Defines package + XDG target. `validateMeta` in `lib/domains/scan.nix` **throws unless exactly one** of `xdg` (full directory → `~/.config/<name>`), `xdgFile` (single file), or `customXdg` (handled by `home.nix`) is set — **or** the feature ships a `system.nix` (system-only features, e.g. `system/*`, omit the XDG target).

```nix
{
  package = "zellij";        # Nix package name (installed when domain enabled)
  xdg = "zellij";            # -> ~/.config/zellij (full dir) — or xdgFile/customXdg
  description = "Terminal multiplexer";
}
```

### render.nix

The heart of the theme system: a function taking `{ themesLib, themeName, homeDirectory, ... }` (see `lib/render.nix`, `renderDomainOutputsFor`) and returning `[{ path, text, checks? }]`. `path` is repo-relative; the framework maps it to the correct XDG location. Rendered outputs can carry `checks` (e.g. "this ghostty color must equal `palette 5`") that the theme checks assert.

## Framework (`lib/domains/`)

- **`scan.nix`** — `readDir` over `/domains/` → category → name, imports each `meta.nix`, validates it, and produces `entries` + `systemEntries` (features with a `system.nix`). Exposed to every builder via `host.scan.domains`.
- **`module.nix`** — `mkDomainModule` auto-generates a home-manager module per feature:
  - `baseModule`: `domains.<cat>.<name>.enable` option, `home.packages` from `meta.package`, `home.file` for rendered outputs;
  - `configSourceModule`: recursive walk of `config/` → `xdg.configFile` symlinks (skipping `.gitignore`, `node_modules`, and `meta.mutable` files);
  - `renderOverrideModule`: filters rendered files by `mutable`;
  - plus the feature's custom `home.nix` if present.
  - `mkNixosSystemModule` imports `system.nix` when present (each system side self-gates on its own `domains.<cat>.<name>.enable`; `host.type` decides whether system sides are built at all).

There is **no** `lib/domains/activation.nix` (README is stale); activation happens through home-manager `xdg.configFile` and, in VMs, `modules/vm/host-mount.nix` gives live access to the host repo.

## Domain Inventory (27)

| Category | Name | Package | XDG | Render | home | system | Purpose |
|---|---|---|---|---|---|---|---|
| agents | cursor-cli | cursor-cli | custom | — | — | — | Cursor AI CLI (meta-only) |
| agents | opencode | opencode | opencode | ✅ | ✅ | — | AI coding agent: 22 LSPs, themed TUI, API key from sops |
| bar | i3status | *(none)* | i3status | ✅ | ✅ | — | i3 status bar (themed blocks) |
| editor | nvim | *(pkgs.neovim in home)* | nvim | ✅ | ✅ | — | Neovim: backend adapters/engines, treesitter, Lua tests |
| files | yazi | *(none)* | yazi | ✅ | ✅ | — | Terminal file manager |
| git | lazygit | lazygit | lazygit | ✅ | ✅ | — | Git TUI |
| http-client | posting | posting | posting | ✅ | ✅ | — | Terminal HTTP client |
| launcher | rofi | rofi | rofi | ✅ | ✅ | — | App launcher |
| nix | nh | nh | custom | — | — | — | Nix CLI helper (meta-only) |
| remote | ssh | openssh | custom | — | ✅ | ✅ | SSH client+agent (home) and sshd (system, per-host opt-in) |
| security | age | age | custom | — | — | — | age encryption (meta-only) |
| security | sops | sops | custom | — | — | — | sops+age secrets (meta-only) |
| session | x11 | *(none)* | custom | ✅ | ✅ | — | X11 autostart/session |
| shell | carapace | carapace | custom | — | ✅ | — | Shell completion engine |
| shell | nushell | nushell | nushell | ✅ | ✅ | — | Nushell config (themed) |
| shell | starship | starship | `starship.toml` (xdgFile) | ✅ | ✅ | — | Prompt (themed) |
| sql-client | rainfrog | rainfrog | rainfrog | ✅ | ✅ | — | TUI DB manager |
| sql-client | sqlit | sqlit-tui | sqlit | ✅ | ✅ | — | TUI SQL browser |
| system | audio | *(none)* | — | — | — | ✅ | PipeWire with ALSA/PulseAudio compat |
| system | clipboard | *(none)* | — | — | — | ✅ | xclip + xsel |
| system | container | *(none)* | — | — | — | ✅ | Docker + Podman, kubectl, lazydocker |
| system | git | *(none)* | — | — | — | ✅ | System-level Git |
| system | graphical | *(none)* | — | — | — | ✅ | X11, LightDM (themed), libinput, dbus, XDG portals |
| system | monitoring | *(none)* | — | — | — | ✅ | btop |
| system | network | *(none)* | — | — | — | ✅ | wget, curl, unzip |
| system | search | *(none)* | — | — | — | ✅ | fd, ripgrep, fzf |
| terminal | ghostty | ghostty | ghostty | ✅ | ✅ | — | GPU terminal (themed) |
| terminal | tmux | tmux | `tmux/tmux.conf` (xdgFile) | ✅ | ✅ | — | Terminal multiplexer |
| terminal | zellij | zellij | zellij | ✅ | ✅ | — | Multiplexer (layout.nix + theme.nix) |
| wm | i3 | *(none)* | i3 | ✅ | — | ✅ | i3 WM: themed config (home) + `services.xserver.windowManager.i3` (system) |

Note: the `home`/`system` columns mark which optional sides a feature ships. Domains with `*(none)*` package rely on their module or system side for installation. `host.type` decides which sides are built — `nixos` hosts build both, `home`-only hosts (e.g. mint) build only home sides.

## Notable Domains

### `agents/opencode`

The most complex domain. `home.nix` + `config/opencode.jsonc` wire the opencode agent with **22 LSP servers** (nixd, lua-ls, rust-analyzer, gopls, pyright, ts/js, html/css/json, yaml, bash, marksman, jdtls, phpactor, docker, terraform-ls, clojure-lsp, lemminx, clangd, vue, taplo; intelephense disabled). The provider API key comes from sops via `{file:~/.secrets/opencode-go-key}` (see [Secrets](secrets.md)). `render.nix` emits a themed `tui.json` + `themes/angst.json`. Git history: `50e80de` added the API key, `84b7ab8` fixed decryption, `e117d52` added LSPs, `b622a81` enabled the experimental feature.

### `editor/nvim`

A Lua config with a pluggable backend (`config/lua/backend/`):
- `adapters/*.lua` — 28 per-language definitions `{filetypes, lsp, lsp_cmd, formatter, treesitter}` (e.g. `json.lua`);
- `engines/` — completion/formatter/linter/lsp/treesitter drivers; `engines/treesitter.lua` registers grammar mappings (sh→bash, jsonc→json…), augroups, and prepends `~/.local/share/tree-sitter(-fixed)` to rtp;
- `shared/` — AdapterLoader/Scanner/Tool, LspTool; `frontend/`, `common/`, `config/` (themed `palette.lua`), `infra/`, `queries/`.
- Tests live in `config/tests/` (`run.sh` → `bootstrap.lua` → plenary suite at `tests/adapters/suite.lua`: loader_scanner, lsp_settings, inlay_hints, engine_mappings, startup). CI runs them via `.github/workflows/nvim-tests.yml`. Recent fixes: `be87346` jsonc→json treesitter mapping; `163d922` re-apply highlight on reopen.

### `wm/i3`

One of two features with a `system.nix` (alongside `remote/ssh`): `system.nix` enables `services.xserver.windowManager.i3` (asserting `system.graphical`), while the themed i3 config ships via `config/` + `render.nix`. Note `profiles/desktop.nix` currently has i3/i3status **commented out** (the desktop profile enables rofi/ghostty/x11).

## Toolchains (`/toolchains/`)

23 language toolchains (+ `toolchains/default.nix` aggregator): bash, blade, c, clojure, conf, css, docker, go, html, java, javascript, json, just, lua, markdown, nix, php, python, rust, terraform, toml, xml, yaml.

Each file calls `mkToolchain` (`lib/toolchain.nix`) with `{ runtime, lsp, formatter, linter, tools, packageManager, treesitter }`; the builder unions them into `home.packages` and collects `treesitterGrammars`. Examples: `rust.nix` (rustc/cargo + rust-analyzer + clippy/rustfmt + tree-sitter-rust); `nix.nix` (nil+nixd, nixfmt, statix+deadnix, nix-output-monitor+nix-tree); `javascript.nix` (nodejs+bun, 5 LSPs incl. vue/angular/prisma, prettierd, eslint_d).

`lib/treesitter.nix` builds cross-glibc parsers: copies each grammar `parser` → `<lang>.so` with `patchelf --set-rpath`, and copies `queries/` dirs; `lang` = pname minus `tree-sitter-`, `-` → `_`. Selected via `host.toolchains` in the host decl (`"*"` or a validated list — unknown names throw at eval).

## Change Guidance

- **Add a domain**: create the dir + `meta.nix`, optionally `home.nix` (user side) / `system.nix` (system side), `render.nix`, `config/`. Enable via a profile (`"category.name"` in `profiles/<name>.nix`'s `enable` list). Rendered outputs follow from `render.nix`; static files from `config/`.
- **System-only features**: omit the XDG target from `meta.nix` and ship a `system.nix` (e.g. `system/*`). They only apply on `nixos` hosts.
- **Cross-cutting features** (e.g. `remote/ssh`): put the user side in `home.nix` and the system side in `system.nix`; enable the feature once and the builder routes it by host type.
- **The `mutable` meta flag** excludes files from render-override, useful for user-local state inside a config dir.
- **Keep `meta.nix` valid** — `scan.nix` throws on malformed meta, and any host build fails.
- **nvim changes** should keep `config/tests/` green (`bash tests/run.sh` or CI nvim-tests); treesitter grammar mapping lives in `engines/treesitter.lua`.
- **Toolchain changes** flow into dev shells and home packages automatically once the file exists; verify with `nix eval .#nixosConfigurations.ci.config.home-manager.users.runner.packages` (ci host uses `toolchains = ["nix"]`) or a full build.
