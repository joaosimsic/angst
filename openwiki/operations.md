# Operations

## Dev Shells

Two dev shells are available for working on the repository:

### Safe Shell (`nix develop .#safe`)

A controlled editing environment providing neovim with Tree-sitter parsers, LSPs, formatters, and runtimes — all from Nix. The key benefit: Tree-sitter parsers link against Nix's glibc, so they work on hosts with older system glibc (e.g., Debian 12).

```bash
nix develop .#safe
```

### Dev Shell (`nix develop .#dev`)

Full development environment with everything from safe plus Rust, QEMU, angst CLI, and VM CLI.

```bash
nix develop .#dev
```

### Shell CLI (standalone)

After installing via `nix profile install .#shell`, you can enter shell modes without `nix`:

```bash
shell safe
shell dev
```

The shell CLI wraps the same environments but execs your preferred shell with correct PATH and tree-sitter symlinks — no `nix develop` invocation needed at runtime.

### Tree-sitter Compatibility

The controlled dev shell solves a specific problem: Nix-built tree-sitter parsers require Nix's glibc (≥2.38). On hosts with older glibc (Debian 12: 2.36, Ubuntu 22.04: 2.35), loading parsers via `uv_dlopen` fails because the system `libc.so.6` wins over the parser's RPATH. Inside the dev shell, neovim itself runs from Nix and links against Nix's glibc, so all `dlopen`'d parsers resolve correctly.

## Checks / CI

### Full Check Suite

```bash
nix run .#check
```

Equivalent to `nix flake check --print-build-logs`. Runs the full suite:

| Check | What it catches |
|-------|-----------------|
| `lint-themes` | Broken themes or invalid domain theme renders |
| `lint-desktop` | Invalid i3 and i3status configs (all themes) |
| `lint-shell` | Invalid starship and nushell configs (all themes) |
| `theme-rendered` | Theme tokens not appearing in rendered output |
| `theme-override` | Theme option override not propagating into configs |
| `theme-semantic-distinct` | Duplicate semantic color roles within a theme |
| `home-theme-override-test` | Home-manager activation for theme override |
| `nixos-personal` | Full NixOS system evaluation for personal host |
| `home-joao` | Standalone home-manager activation for personal profile |

### Targeted Checks

```bash
nix run .#lint-themes    # Fastest — eval-only
nix run .#lint-desktop   # i3 + i3status per theme
nix run .#lint-shell     # starship + nushell per theme
```

### CI

GitHub Actions runs two workflows on every push and pull request:

1. **checks** (`.github/workflows/checks.yml`): Runs the full `nix flake check` suite as separate parallel jobs — `lint-themes`, `lint-desktop`, `lint-shell`, `theme-rendered`, `theme-override`, `theme-semantic-distinct`, plus a `vm-tests` job that runs `cargo fmt --check && cargo test --workspace --locked` for the VM Rust workspace.
2. **OpenWiki** (`.github/workflows/openwiki-update.yml`): Scheduled daily job that regenerates the `/openwiki/` documentation.

Note: The first CI run builds the full NixOS closure and takes a while; subsequent runs reuse the Nix store cache.

## VM Workflow

### Building and Running

```bash
# Build VM outputs
nix run .#vm

# Run with GUI
nix run .#vm-run

# Run headless (no QEMU window)
nix run .#vm-run -- --headless
```

### VM Features

- **9p filesystem mounts** — The angst repo is mounted into the VM at `/host/.../proj/angst`, enabling live editing from inside the VM with changes reflected on the host
- **SPICE vdagent** — Clipboard copy-paste between host and VM
- **SSH key injection** — Host SSH public keys are automatically provisioned into the VM
- **Host config mount** — `/home/joao/.config/angst` is symlinked to the host mount, so config changes inside the VM are saved to the host
- **Display** — `Virtual-1 1920x1080` with VirtIO GPU and modesetting driver
- **Specs** — 4 vCPUs, 4 GiB RAM, 16 GB disk

### MCP Server

The VM tool can run as an MCP server for AI agent integration:

```bash
# Start the MCP server on port 8765
vm mcp
```

OpenCode is configured to connect to it via `/opencode.json`. This allows AI coding agents to manage the VM lifecycle during development.

## Hot-Reload Workflow

The `angst render` and `angst watch` commands enable fast iteration on themes and domain configs without a full Nix rebuild:

```bash
# One-time render
angst render

# Continuous watch
angst watch
```

**Workflow:**
1. Edit a domain's `render.nix` or a theme's color values
2. `angst render` writes the new configs to `~/.config/<app>/`
3. If i3 is running, `i3-msg reload` applies the changes immediately
4. The watch mode (`angst watch`) uses `watchexec` to automate this on every save

## Lint and Format Commands

Reference from `/.opencode/AGENTS.md`:

### Nix
```bash
statix check .              # Lint (statix)
deadnix .                   # Dead code detection
nixfmt .                    # Format
nixfmt --check .            # Format check
```

### Lua
```bash
stylua .                    # Format
stylua --check .            # Format check
```

### Rust (tools/vm/)
```bash
cargo clippy --all-targets --all-features -- -D warnings   # Lint
cargo fmt --all                                             # Format
cargo test --workspace                                      # Test
```

## Common Tasks

### Adding a new host
1. Create `hosts/<name>/default.nix` with `system`, `theme`, `user`, `monitors`
2. Create `hosts/<name>/configuration.nix` for NixOS config
3. Create `hosts/<name>/hardware.nix` for hardware-specific config
4. Create `hosts/<name>/home.nix` enabling desired domains
5. The host is auto-discovered by `scanHosts.nix`

### Adding a new domain
1. Create `domains/<category>/<name>/meta.nix` with package metadata
2. Optionally add `render.nix` for theme-aware config generation
3. Optionally add `config/` directory for static files
4. Optionally add `module.nix` for custom home-manager logic
5. Optionally add `nixos.nix` for system integration
6. Enable it in a host's `home.nix` or `/common/home.nix`

### Adding a new theme
1. Create `/themes/<name>.nix` following the schema
2. Run `nix run .#lint-themes` to validate
3. Set `theme = "<name>";` in a host's `default.nix`

### Adding a new toolchain
1. Create `/toolchains/<name>.nix` using `mkToolchain`
2. It is auto-discovered and included in dev shells and home-manager

## Source Map

| File | Role |
|------|------|
| `/shell.md` | Controlled dev shell documentation |
| `/docs/checks.md` | Check suite documentation |
| `/docs/vm/README.md` | VM CLI documentation |
| `/lib/flake/shared.nix` | Dev shell definitions, angst CLI |
| `/.github/workflows/checks.yml` | CI workflow |
| `/tools/vm/flake.nix` | VM build and run scripts |
| `/lib/treesitter.nix` | Tree-sitter grammar builder |
| `/opencode.json` | OpenCode MCP configuration |
| `/.opencode/AGENTS.md` | Lint/format reference |

## Change Guidance

### Dev Shells
- **Safe shell** (editing environment): defined in `/lib/flake/default.nix` (lines ~155-163). Contains `neovim`, `git`, and `allToolchainPackages`.
- **Dev shell** (full development): defined in `/lib/flake/default.nix` (lines ~165-171). Adds `angstCli`, Rust toolchain, QEMU, VM tools.
- **Shell CLI** (standalone): `shellWrapped` in `/lib/flake/shared.nix` (lines ~308-321). Environment variables are baked in via `makeWrapper`.
- **Tree-sitter hook** (`treesitterShellHook`): creates symlinks for parsers/queries. If you change the tree-sitter output structure in `/lib/treesitter.nix`, update this hook.
- **SSH host shell paths** (`SHELL_ENABLED_SHELLS`): constructed in `flake.nix` from interactive domains. Adding `interactive = true` to a shell domain's `meta.nix` includes it here.

### Checks / CI
- **CI workflow** (`.github/workflows/checks.yml`): runs individual checks as separate jobs on every push/PR. Each job builds a single check derivation.
- **Check definitions** (`/lib/flake/checks.nix`): assembles all checks from theme lint modules and NixOS/home-manager evaluations.
- **Adding a new check**: Create a check file in `/lib/checks/`, then wire it into `/lib/flake/checks.nix`.
- **CI secrets**: None required — Nix evaluation and builds use the public Nix cache. The VM tests use the `magic-nix-cache` action.

### VM Workflow
- **VM run shim** (`vmRunShim` in `shared.nix`, lines ~220-269): handles SSH key provisioning, headless mode, disk image management, and QEMU port forwarding.
- **VM build** (`tools/vm/flake.nix`): constructs `allHostVms` by iterating over NixOS configurations. Adding a new host with `specialisation.vm` automatically includes it.
- **SSH key injection**: reads from `ssh-agent` and `~/.ssh/*.pub`, writes to `~/.local/state/vm/keys/<host>/authorized_keys`.
- **Port forwarding**: hardcoded as `hostfwd=tcp::2222-:22` in `vmRunShim`. Change in `QEMU_NET_OPTS`.

### Hot-Reload
- `angst render` calls `nix eval --impure "$repo_root#lib.renderDomainOutputsFor"` — requires an `angstCli` flake app that's kept up to date.
- The `--reload` flag runs `i3-msg reload` — only works when `I3SOCK` is set (i3 running).
- `angst watch` monitors `themes/`, `domains/`, and `hosts/<host>/` directories. Adding a new watched directory requires editing the `watch_cmd` function.

### Lint and Format
- **Statix** (Nix lint) checks for anti-patterns in `*.nix` files. Run `statix check .` after structural changes.
- **Deadnix** detects unused Nix bindings. Run after refactoring.
- **Nixfmt** is the flake formatter (`formatter.${system} = pkgs.nixfmt` in `flake.nix`). Run `nix fmt` before committing.
- **Stylua** formats Lua files (Neovim config). Run `stylua .` after editing `/domains/editor/nvim/`.
- **Rust lints** (clippy + fmt) are checked in CI for `/tools/vm/`. Run `cargo fmt --all && cargo clippy --all-targets --all-features` before committing VM changes.
