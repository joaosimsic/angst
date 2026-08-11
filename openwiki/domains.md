# Domains

Domains are the **unit of user-space configuration** in angst. Each domain describes one application or tool — what package to install, where its config lives, and how to render theme-aware configuration files. There are currently **21 domains across 14 categories** (plus a dead `llm/opencode` dir without `meta.nix`).

## Domain Anatomy

```
domains/<category>/<name>/
├── meta.nix       # Required: package name, XDG target, description, building type
├── module.nix     # Optional: custom home-manager module (only when auto-gen isn't enough)
├── render.nix     # Optional: theme-aware config generator
├── config/        # Optional: static config files (symlinked via xdg.configFile)
└── nixos.nix      # Optional: NixOS module (only wm/i3 has one)
```

### meta.nix

Defines package + XDG target. `validateMeta` in `lib/domains/scan.nix` **throws unless exactly one** of `xdg` (full directory → `~/.config/<name>`), `xdgFile` (single file), or `customXdg` (handled by `module.nix`) is set. `building` filters a domain into home vs NixOS entries (`"home"` default, `"nixos"`, or `"both"`).

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

- **`scan.nix`** — `readDir` over `/domains/` → category → name, imports each `meta.nix`, validates it, and produces `homeEntries`/`nixosEntries` (each `{ category, name, meta, path, hasRender, hasModule, hasConfigDir, hasNixos }`). Exposed to every builder via `host.scan.domains`.
- **`module.nix`** — `mkDomainModule` auto-generates a home-manager module per home entry:
  - `baseModule`: `domains.<cat>.<name>.enable` option, `home.packages` from `meta.package`, `home.file` for rendered outputs;
  - `configSourceModule`: recursive walk of `config/` → `xdg.configFile` symlinks (skipping `.gitignore`, `node_modules`, and `meta.mutable` files);
  - `renderOverrideModule`: filters rendered files by `mutable`;
  - plus the domain's custom `module.nix` if present.
  - `mkNixosDomainModule` imports `nixos.nix` when present.

There is **no** `lib/domains/activation.nix` (README is stale); activation happens through home-manager `xdg.configFile` and, in VMs, `modules/vm/host-mount.nix` gives live access to the host repo.

## Domain Inventory (21)

| Category | Name | Package | XDG | Render | Module | NixOS | Purpose |
|---|---|---|---|---|---|---|---|
| agents | cursor-cli | cursor-cli | custom | — | — | — | Cursor AI CLI (meta-only) |
| agents | opencode | opencode | opencode | ✅ | ✅ | — | AI coding agent: 22 LSPs, themed TUI, API key from sops |
| bar | i3status | *(none)* | i3status | ✅ | ✅ | — | i3 status bar (themed blocks) |
| editor | nvim | *(pkgs.neovim in module)* | nvim | ✅ | ✅ | — | Neovim: backend adapters/engines, treesitter, Lua tests |
| files | yazi | *(none)* | yazi | ✅ | ✅ | — | Terminal file manager |
| git | lazygit | lazygit | lazygit | ✅ | ✅ | — | Git TUI |
| http-client | posting | posting | posting | ✅ | ✅ | — | Terminal HTTP client |
| launcher | rofi | rofi | rofi | ✅ | ✅ | — | App launcher |
| nix | nh | nh | custom | — | — | — | Nix CLI helper (meta-only) |
| security | age | age | custom | — | — | — | age encryption (meta-only) |
| security | sops | sops | custom | — | — | — | sops+age secrets (meta-only) |
| session | x11 | *(none)* | custom | ✅ | ✅ | — | X11 autostart/session |
| shell | carapace | carapace | custom | — | ✅ | — | Shell completion engine |
| shell | nushell | nushell | nushell | ✅ | ✅ | — | Nushell config (themed) |
| shell | starship | starship | `starship.toml` (xdgFile) | ✅ | ✅ | — | Prompt (themed) |
| sql-client | rainfrog | rainfrog | rainfrog | ✅ | ✅ | — | TUI DB manager |
| sql-client | sqlit | sqlit-tui | sqlit | ✅ | ✅ | — | TUI SQL browser |
| terminal | ghostty | ghostty | ghostty | ✅ | ✅ | — | GPU terminal (themed) |
| terminal | tmux | tmux | `tmux/tmux.conf` (xdgFile) | ✅ | ✅ | — | Terminal multiplexer |
| terminal | zellij | zellij | zellij | ✅ | ✅ | — | Multiplexer (layout.nix + theme.nix) |
| wm | i3 | *(none)* | i3 | ✅ | — | ✅ | i3 WM (`building = "both"`, only `nixos.nix` domain) |

Note: domains with `*(none)*` package rely on the module or system/capability for installation. 16 domains have `render.nix` + `config/`; 16 have a custom `module.nix`; only `wm/i3` has `nixos.nix`.

## Notable Domains

### `agents/opencode`

The most complex domain. `module.nix` + `config/opencode.jsonc` wire the opencode agent with **22 LSP servers** (nixd, lua-ls, rust-analyzer, gopls, pyright, ts/js, html/css/json, yaml, bash, marksman, jdtls, phpactor, docker, terraform-ls, clojure-lsp, lemminx, clangd, vue, taplo; intelephense disabled). The provider API key comes from sops via `{file:~/.secrets/opencode-go-key}` (see [Secrets](secrets.md)). `render.nix` emits a themed `tui.json` + `themes/angst.json`. Git history: `50e80de` added the API key, `84b7ab8` fixed decryption, `e117d52` added LSPs, `b622a81` enabled the experimental feature.

### `editor/nvim`

A Lua config with a pluggable backend (`config/lua/backend/`):
- `adapters/*.lua` — 28 per-language definitions `{filetypes, lsp, lsp_cmd, formatter, treesitter}` (e.g. `json.lua`);
- `engines/` — completion/formatter/linter/lsp/treesitter drivers; `engines/treesitter.lua` registers grammar mappings (sh→bash, jsonc→json…), augroups, and prepends `~/.local/share/tree-sitter(-fixed)` to rtp;
- `shared/` — AdapterLoader/Scanner/Tool, LspTool; `frontend/`, `common/`, `config/` (themed `palette.lua`), `infra/`, `queries/`.
- Tests live in `config/tests/` (`run.sh` → `bootstrap.lua` → plenary suite at `tests/adapters/suite.lua`: loader_scanner, lsp_settings, inlay_hints, engine_mappings, startup). CI runs them via `.github/workflows/nvim-tests.yml`. Recent fixes: `be87346` jsonc→json treesitter mapping; `163d922` re-apply highlight on reopen.

### `wm/i3`

Only domain with `nixos.nix` (`building = "both"`): enables i3 as the system WM. Note `profiles/desktop.nix` currently has i3/i3status **commented out** (the desktop profile enables rofi/ghostty/x11).

## Toolchains (`/toolchains/`)

23 language toolchains (+ `toolchains/default.nix` aggregator): bash, blade, c, clojure, conf, css, docker, go, html, java, javascript, json, just, lua, markdown, nix, php, python, rust, terraform, toml, xml, yaml.

Each file calls `mkToolchain` (`lib/toolchain.nix`) with `{ runtime, lsp, formatter, linter, tools, packageManager, treesitter }`; the builder unions them into `home.packages` and collects `treesitterGrammars`. Examples: `rust.nix` (rustc/cargo + rust-analyzer + clippy/rustfmt + tree-sitter-rust); `nix.nix` (nil+nixd, nixfmt, statix+deadnix, nix-output-monitor+nix-tree); `javascript.nix` (nodejs+bun, 5 LSPs incl. vue/angular/prisma, prettierd, eslint_d).

`lib/treesitter.nix` builds cross-glibc parsers: copies each grammar `parser` → `<lang>.so` with `patchelf --set-rpath`, and copies `queries/` dirs; `lang` = pname minus `tree-sitter-`, `-` → `_`. Selected via `host.toolchains` in the host decl (`"*"` or a validated list — unknown names throw at eval).

## Change Guidance

- **Add a domain**: create the dir + `meta.nix`, enable via a profile (`mkDomainEnable "category.name"` in `profiles/<name>.nix`). Rendered outputs follow from `render.nix`; static files from `config/`.
- **The `mutable` meta flag** excludes files from render-override, useful for user-local state inside a config dir.
- **Keep `meta.nix` valid** — `scan.nix` throws on malformed meta, and any host build fails.
- **nvim changes** should keep `config/tests/` green (`bash tests/run.sh` or CI nvim-tests); treesitter grammar mapping lives in `engines/treesitter.lua`.
- **Toolchain changes** flow into dev shells and home packages automatically once the file exists; verify with `nix eval .#nixosConfigurations.ci.config.home-manager.users.runner.packages` (ci host uses `toolchains = ["nix"]`) or a full build.
