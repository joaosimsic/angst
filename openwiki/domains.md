# Domains

Domains are the **unit of user-space configuration** in angst. Each domain describes one application or tool — what package to install, where its config lives, and how to render theme-aware configuration files.

## Domain Anatomy

Every domain lives under `/domains/<category>/<name>/` and follows this structure:

```
domains/<category>/<name>/
├── meta.nix       # Required: package name, XDG target, description
├── module.nix     # Optional: custom home-manager module (rarely needed)
├── render.nix     # Optional: theme-aware config generator
├── config/        # Optional: static config files (symlinked by activation)
└── nixos.nix      # Optional: system-level NixOS module
```

### meta.nix

Defines the domain's metadata — package, binary, XDG target, and description.

```nix
{
  package = "neovim";          # Nix package name
  binary = "nvim";             # Binary name (for shell entries)
  description = "Neovim editor";
  # For full directory symlink:
  xdg = "nvim";                # -> ~/.config/nvim
  # For single file:
  xdgFile = "starship.toml";   # -> ~/.config/starship.toml
  interactive = true;          # Is this an interactive shell app?
  customXdg = true;            # Skip auto symlink, handle in module.nix
}
```

### module.nix (optional)

A custom home-manager module for domains needing special logic beyond the auto-generated base. Most domains don't need this — the framework provides a sensible default via `/lib/domains/module.nix`.

### render.nix (optional)

The heart of the theme system. A function that takes `{ themesLib, themeName, homeDirectory, ... }` and returns a list of `{ path, text, checks? }` objects.

```nix
t: themesLib.get themeName;  # Get all theme tokens

{
  path = "domains/terminal/ghostty/config/config";
  text = ''
    theme = ${t.palette.base}
    background = ${t.ui.bg}
    foreground = ${t.ui.fg}
    ...
  '';
  checks = [
    { name = "ghostty-magenta"; require = [ "palette 5 = ${t.ansi.magenta}" ]; }
  ];
}
```

The `path` is relative to the repository root. The domain framework strips the `domains/<category>/<name>/config/` prefix and maps it to the correct XDG location.

### config/ directory (optional)

Static configuration files that get symlinked to `~/.config/<app>/` during home-manager activation (via `/lib/domains/activation.nix`). In a VM, the symlink targets the host 9p mount path for live editing.

### nixos.nix (optional)

A system-level NixOS module. Used by domains that need system integration — e.g., `wm/i3/nixos.nix` for enabling X11 window manager services.

## Domain Framework

The framework lives in `/lib/domains/` and provides automatic discovery, module generation, and activation:

### scan.nix (`/lib/domains/scan.nix`)

Recursively scans `/domains/` for all directories containing `meta.nix`. Returns a list of `homeEntries` (for home-manager) and `nixosEntries` (for NixOS). Each entry has `{ category, name, meta, path, hasRender, hasModule, hasConfigDir, hasNixos }`.

### module.nix (`/lib/domains/module.nix`)

For each domain entry, constructs a home-manager module:

1. Creates `domains.<category>.<name>.enable` option
2. When enabled: installs `meta.package`, generates `home.file` entries from `render.nix` output (if no `config/` dir), symlinks `config/` directory (if it exists), imports custom `module.nix` (if it exists)
3. For render-based domains: calls `render.nix` with `themesLib` and `config.theme` to produce XDG-mapped `home.file` entries

### activation.nix (`/lib/domains/activation.nix`)

Creates home-manager activation scripts that symlink the domain's `config/` directory to `~/.config/<app>`, with a fallback to the host 9p mount path when running inside a VM.

## Available Domains

### Editor
| Domain | meta.package | render.nix | module.nix | nixos.nix |
|--------|-------------|------------|------------|-----------|
| `editor/nvim` | `neovim` | Yes | Yes | — |

### Shell
| Domain | meta.package | render.nix | module.nix | nixos.nix |
|--------|-------------|------------|------------|-----------|
| `shell/nushell` | `nushell` | Yes | Yes | — |
| `shell/starship` | `starship` | Yes | Yes | — |

### Terminal
| Domain | meta.package | render.nix | module.nix | nixos.nix |
|--------|-------------|------------|------------|-----------|
| `terminal/ghostty` | `ghostty` | Yes | Yes | — |
| `terminal/tmux` | `tmux` | — | Yes *(no-op)* | — |
| `terminal/zellij` | `zellij` | Yes | Yes | — |

### Window Manager
| Domain | meta.package | render.nix | module.nix | nixos.nix |
|--------|-------------|------------|------------|-----------|
| `wm/i3` | `i3` | Yes | Yes | Yes |

### Bar
| Domain | meta.package | render.nix | module.nix | nixos.nix |
|--------|-------------|------------|------------|-----------|
| `bar/i3status` | `i3status` | Yes | Yes | — |

### Launcher
| Domain | meta.package | render.nix | module.nix | nixos.nix |
|--------|-------------|------------|------------|-----------|
| `launcher/rofi` | `rofi` | Yes | Yes | — |

### Files
| Domain | meta.package | render.nix | module.nix | nixos.nix |
|--------|-------------|------------|------------|-----------|
| `files/yazi` | `yazi` | Yes | Yes | — |

### LLM
| Domain | meta.package | render.nix | module.nix | nixos.nix |
|--------|-------------|------------|------------|-----------|
| `llm/opencode` | `opencode` | Yes | — | — |
| `llm/cursor-cli` | `cursor-cli` | — | — | — |

### HTTP Client
| Domain | meta.package | render.nix | module.nix | nixos.nix |
|--------|-------------|------------|------------|-----------|
| `http-client/posting` | `posting` | Yes | — | — |

### SQL Client
| Domain | meta.package | render.nix | module.nix | nixos.nix |
|--------|-------------|------------|------------|-----------|
| `sql-client/sqlit` | `sqlit` | Yes | — | — |

### Session
| Domain | meta.package | render.nix | module.nix | nixos.nix |
|--------|-------------|------------|------------|-----------|
| `session/x11` | — | — | Yes | — |

## Toolchains

Toolchains (`/toolchains/`) provide declarative language development environments:

```
toolchains/
├── default.nix   # Auto-discovers all .nix files
├── bash.nix
├── blade.nix
├── c.nix
├── css.nix
├── docker.nix
├── go.nix
├── html.nix
├── java.nix
├── javascript.nix
├── json.nix
├── lua.nix
├── nix.nix
├── php.nix
├── python.nix
├── rust.nix
├── terraform.nix
└── xml.nix
```

Each toolchain calls `mkToolchain` (`/lib/toolchain.nix`) which takes an attrset with `runtime`, `packageManager`, `lsp`, `linter`, `formatter`, `treesitter`, `tools` keys.

Toolchains are consumed by:
- **home-manager**: All toolchain packages are added to `home.packages` via `/common/home.nix` importing `../toolchains`
- **Dev shells**: `allToolchainPackages` is aggregated in `/lib/flake/shared.nix` and included in dev shell packages
- **Tree-sitter**: `allGrammars` are built by `/lib/treesitter.nix` for cross-glibc compatibility

## Common Configuration

`/common/home.nix` enables the core set of domains for all hosts:

- `shell/nushell`, `shell/starship`
- `terminal/zellij`
- `llm/opencode`, `llm/cursor-cli`
- `editor/nvim`
- `files/yazi`
- `sql-client/sqlit`
- `http-client/posting`

Host-specific `home.nix` files add domain enables on top (e.g., `wm/i3`, `bar/i3status`, `launcher/rofi`, `session/x11` for the personal workstation).

## Source Map

| File | Role |
|------|------|
| `/lib/domains/default.nix` | Framework entry: combines scan + module |
| `/lib/domains/scan.nix` | Auto-discovers all domains |
| `/lib/domains/module.nix` | Generates home-manager modules per domain |
| `/lib/domains/activation.nix` | XDG symlink activation scripts |
| `/lib/toolchain.nix` | `mkToolchain` builder |
| `/lib/treesitter.nix` | Tree-sitter grammar builder (glibc-safe) |
| `/common/home.nix` | Shared domain enables |
| `/common/user.nix` | User definition |
| `/common/capabilities.nix` | Shared NixOS capability enables |

## Change Guidance

### Adding a new domain
1. Create `domains/<category>/<name>/meta.nix` — define package, XDG target, description
2. Add `render.nix` if the domain should consume theme tokens. The function signature: `{ themesLib, themeName, hostConfig, fontFamily, monitors, homeDirectory, checkHelpers }` → list of `{ path, text, checks? }`
3. Add static `config/` files for non-themed defaults
4. Add `module.nix` only if the auto-generated module (`/lib/domains/module.nix`) isn't sufficient — common reasons: `programs.neovim` enable, custom activation scripts, `customXdg = true`
5. Add `nixos.nix` only if system-level integration is needed (e.g., X11 WM enablement)
6. Enable in `common/home.nix` for all hosts, or in a host-specific `home.nix`
7. Run `nix run .#lint-themes` and the relevant domain rendering check

### Modifying domain framework
- `/lib/domains/scan.nix` — Controls how domains are discovered and validated. Key behavior: validates `xdg` / `xdgFile` / `customXdg` mutual exclusion
- `/lib/domains/module.nix` — Auto-generated home-manager module for each domain. Creates `home.file` entries from `render.nix` output or symlinks `config/` directory
- `/lib/domains/activation.nix` — Creates activation script entries for XDG symlinks with VM host-mount fallback
- `/lib/build/mkHome.nix` — Orchestrates domain module injection into home-manager; passes `themesLib`, `hostTheme`, `userConfig`, `monitors` as `extraSpecialArgs`

### Adding a toolchain
1. Create `/toolchains/<name>.nix` with `mkToolchain { runtime = [...]; lsp = [...]; formatter = [...]; linter = [...]; tools = [...]; treesitter = [...]; }`
2. Auto-discovered by `/lib/flake/shared.nix` — no registration needed
3. Packages appear in `allToolchainPackages` (dev shells) and `allGrammars` (tree-sitter)
4. Toolchains are imported via `/common/home.nix` which does `imports = [ ../toolchains ]`
