# Tools

angst ships three CLI tools and an OpenCode MCP integration for VM management.

## angst CLI — Hot-Reload Renderer and Password Manager

A shell script (`/lib/flake/shared.nix` → `angst`) for rendering theme-aware domain configs without a full Nix rebuild and managing user passwords.

### Commands

```bash
# Render all domain configs to ~/.config/
angst render

# Watch for file changes and re-render automatically
angst watch

# Interactively hash a password and write it to user.env
angst passwd
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--repo PATH` | `$ANGST_REPO` or `git rev-parse --show-toplevel` or `pwd` | Angst repo root |
| `--host HOST` | `$ANGST_HOST` or `personal` | Host name |
| `--theme THEME` | `$ANGST_THEME` or host's configured theme | Theme name |
| `--reload` / `--no-reload` | Reload enabled | Whether to reload i3 after rendering |

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `ANGST_REPO` | Repository root path |
| `ANGST_HOST` | Host name override |
| `ANGST_THEME` | Theme name override |
| `ANGST_RENDER_NO_RELOAD` | Disable i3 reload |
| `ANGST_USERNAME` | Username override (read by the render scripts and Rust CLIs) |
| `ANGST_PASSWORD` | Password hash override (read by NixOS module for user password) |

### How it works

1. Calls `nix eval` to compute rendered configs from all domain `render.nix` files
2. Writes the output files to `~/.config/<app>/` paths
3. Optionally triggers `i3-msg reload` for immediate UI update

The `watch` command uses `watchexec` to monitor the repository for changes and re-render automatically.

### Password Management

The `angst passwd` subcommand (`/scripts/angst.sh`) handles user password setup:

1. Reads `user.env` from the repository root to identify the target host
2. Prompts for a password interactively (with confirmation)
3. Hashes the password using `mkpasswd -m sha-512`
4. Writes or updates `PASSWORD=<hash>` in `user.env`
5. Securely clears password variables from memory after hashing

The hashed password is consumed at Nix build time by `/lib/nixos/default.nix`, which resolves it via `ANGST_PASSWORD` env > `user.env.PASSWORD` > `null` (no password).

## shell CLI — Nix-Aware Dev Shell Entry

A Rust CLI (`/tools/shell/`) that provides controlled development shells without requiring `nix` at runtime.

### Commands

```bash
# Install globally
nix profile install .#shell

# Enter safe mode (neovim + parsers + LSPs + formatters)
shell safe

# Enter dev mode (safe + Rust + QEMU + angst CLI + VM tools)
shell dev
```

### How it works (`/tools/shell/src/runner.rs`)

1. Resolves the user's preferred shell from `SHELL_ENABLED_SHELLS` env var (colon-separated shell paths), falling back to `SHELL` env, then `/bin/bash`
2. Reads `user.env` from the repository via `read_env_value()` for consistent env resolution across tools
3. Symlinks Tree-sitter parsers and queries into `~/.local/share/tree-sitter/`
4. Prepends a Nix-provided `PATH` (baked in at build time via `SHELL_SAFE_PATH`/`SHELL_DEV_PATH`)
5. For dev mode, sources `SHELL_DEV_ENTRY` (sets up SSH agent, loads keys, defines `res()`) before execing the shell
6. For safe mode, execs the resolved host shell directly
7. Sets `IN_NIX_SHELL=impure`, `name`, and `SHELL_MODE` environment variables on exec

The binary is built by Nix and wrapped with store paths, so no `nix` invocation is needed at runtime.

### Use Cases

- **Safe mode**: Tree-sitter parsers work on hosts with older glibc (e.g., Debian 12 with glibc 2.36) because neovim and parsers both link against Nix's glibc
- **Dev mode**: Full development environment with Rust toolchain, QEMU, and angst/VM CLIs

## VM CLI — QEMU Virtual Machine Manager

A Rust CLI + MCP server (`/tools/vm/`) for managing NixOS development VMs.

### Architecture

Three crates in a Cargo workspace:
- **`vm-core`** — Core types and VM lifecycle logic. Provides `SshEngine` (libssh2 wrapper), `VmConfig` (env-var-based with `VM_SSH_PORT`, `VM_SSH_USER`, `NIX_DEFAULT_TARGET_HOST`), `VmProcessController` (background process lifecycle with PID state files in `~/.local/state/vm/`).
- **`vm-cli`** — CLI interface with clap-derived subcommands: `start`, `stop`, `restart`, `status`, `ssh`, `exec`, `copy-to`, `copy-from`, `health`, `logs`, and `mcp` (with its own subcommands). The runner (`vm.rs`) implements the full lifecycle with stale process cleanup and health checks.
- **`vm-mcp`** — Axum HTTP server serving MCP (Model Context Protocol) on port 8765, exposing `vm_exec`, `vm_status`, and `vm_restart` tools for AI agent integration.

### VM Runner Details

The VM runner (`/tools/vm/crates/vm-cli/src/runner/vm.rs`) resolves runtime configuration through a cascading priority system:

- **Target host**: `NIX_TARGET_HOST` env > `user.env HOST` > `NIX_DEFAULT_TARGET_HOST` > `ANGST_HOST` > `generic`
- **Target username**: `ANGST_USERNAME` env > `user.env USERNAME` > `VmConfig.ssh_user` > `joao`

Key lifecycle improvements:
- **Stale QEMU cleanup** (`kill_stale_qemu()`): Terminates existing QEMU processes for the same disk image before starting a new VM, preventing port conflicts and stale state
- **Health check system**: `HealthReport` runs a multi-probe check — QEMU process existence, PID file health, port forwarding (hostfwd) validity, port 2222 reachability, and SSH echo response. Surfaced via `nix run .#vm -- health`
- **Headless auto-detection**: When `DISPLAY` and `WAYLAND_DISPLAY` are both unset, automatically enables `--headless` mode to avoid QEMU window errors on headless systems
- **SSH wait loop**: Polls up to 300 seconds for SSH readiness after QEMU starts, with progress feedback

### CLI Commands

```bash
# Build VM outputs from the flake
nix build .#vm

# Start the VM (builds if needed, polls SSH up to 120s, kills stale QEMU)
nix run .#vm -- start

# Stop the VM (SIGTERM)
nix run .#vm -- stop

# Restart the VM
nix run .#vm -- restart

# Check VM status (process + SSH reachability)
nix run .#vm -- status

# Full health check (QEMU process → port forwarding → SSH echo)
nix run .#vm -- health

# SSH into the VM
nix run .#vm -- ssh

# Execute a command inside the VM
nix run .#vm -- exec "systemctl status"

# Copy files to/from the VM
nix run .#vm -- copy-to /local/path /vm/path
nix run .#vm -- copy-from /vm/path /local/path

# View VM logs
nix run .#vm -- logs

# Run the VM with GUI
nix run .#vm-run

# Run headless (auto-detected or explicit)
nix run .#vm-run -- --headless
```

The `vm-run` script (`/tools/vm/flake.nix`) handles SSH key provisioning (from `ssh-add -L` and `~/.ssh/*.pub`), optionally sets `QEMU_OPTS` for headless mode, and generates VM run scripts for each NixOS configuration's `specialisation.vm`.

### MCP Server

The VM CLI includes an MCP server that exposes VM lifecycle operations via the [Model Context Protocol](https://modelcontextprotocol.io/), enabling AI agents to manage VMs:

```bash
# Start the MCP server as a background daemon
nix run .#vm -- mcp start

# Stop the MCP server
nix run .#vm -- mcp stop

# Run in foreground (for debugging)
nix run .#vm -- mcp run-server
```

## OpenCode MCP Integration

`/opencode.json` configures OpenCode to connect to the VM MCP server:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "vm": {
      "type": "remote",
      "url": "http://localhost:8765/mcp",
      "enabled": true
    }
  }
}
```

This enables AI coding agents to start, stop, and interact with NixOS VMs during development.

## Source Map

| Tool | Source | Key Files |
|------|--------|-----------|
| **angst CLI** | `/lib/flake/shared.nix` | Render/watch shell script |
| **shell CLI** | `/tools/shell/` | `src/main.rs`, `src/runner.rs`, `src/commands.rs`, `Cargo.toml`, `flake.nix` |
| **VM CLI** | `/tools/vm/` | `src/main.rs`, `Cargo.toml`, `flake.nix`, `crates/vm-core/`, `crates/vm-cli/`, `crates/vm-mcp/` |
| **MCP config** | `/opencode.json` | Remote MCP server config |

## Change Guidance

### Modifying the angst CLI
- Source: `/lib/flake/shared.nix` (the `angstCli` `writeShellApplication`), with the implementation in `/scripts/angst.sh`
- The `render` command calls `nix eval --impure "$repo_root#lib.renderDomainOutputsFor"` — any change to the `renderDomainOutputsFor` function in `/lib/flake/default.nix` affects the CLI output
- The `watch` command uses `watchexec` — ensure it's available as a runtime input (`pkgs.watchexec` in `angstCli` definition)
- The `passwd` subcommand calls `mkpasswd` — ensure it's in the `angstCli` runtime inputs (`pkgs.mkpasswd`)
- Environment variable fallback chain: `$ANGST_REPO` → `git rev-parse` → `pwd`
- Repo discovery also checks `$HOME/proj/angst`, `$HOME/.config/angst`, and common project paths

### Modifying the shell CLI
- Source: `/tools/shell/` Rust project (3 source files)
- **`commands.rs`** — CLI argument definition (clap derive). Add new subcommands here.
- **`runner.rs`** — Shell environment setup:
  - `resolve_host_shell()`: Checks `SHELL_ENABLED_SHELLS` env var first, then `SHELL` env, falls back to `/bin/bash`
  - `read_env_value()`: Parses `user.env` for `HOST` and `USERNAME` values — changes to the env file format must update this function
  - `setup_treesitter()`: Symlinks parsers and queries to `~/.local/share/tree-sitter/`
  - `enter()`: Mode-based PATH management and dev hook sourcing
- Key env vars baked in at build time via `makeWrapper`:
  - `SHELL_SAFE_PATH`, `SHELL_DEV_PATH` — PATH overrides (set in `shared.nix`)
  - `SHELL_TS_PARSERS`, `SHELL_TS_QUERIES` — Tree-sitter paths
  - `SHELL_DEV_ENTRY` — Dev hook entry script (sources `shellDevHook` in `shared.nix`)
  - `SHELL_ENABLED_SHELLS` — Colon-separated shell paths for host-specific shells
- **Build**: Built by `tools/shell/flake.nix` as a local flake input. The wrapper (`shellWrapped`) is constructed in `/lib/flake/shared.nix`
- **Testing**: Run `cargo test` from `/tools/shell/`

### Modifying the VM CLI
- Source: `/tools/vm/` Cargo workspace (3 crates: `vm-core`, `vm-cli`, `vm-mcp`)
- **`vm-core`** — Core VM lifecycle logic (config, SSH, process control). `VmConfig` reads from env vars: `VM_SSH_PORT`, `VM_SSH_USER`, `NIX_DEFAULT_TARGET_HOST`. Changes to env var names must be reflected here.
- **`vm-cli`** — CLI interface. Add new commands here. The runner (`vm.rs`) implements:
  - `read_env_value()`: Parses `user.env` for `HOST` and `USERNAME` (shared pattern with shell CLI)
  - `kill_stale_qemu()`: Cleanup logic — update if QEMU process detection changes
  - `HealthReport`: Multi-probe health check — update if new probes are needed
  - `target_host()`/`target_username()`: Priority chain for host/user resolution
- **`vm-mcp`** — MCP server for AI agent integration. The MCP endpoint is configured in `/opencode.json` (port 8765).
- **Build**: Built by `tools/vm/flake.nix`. The flake constructs `allHostVms` by mapping over NixOS configurations.
- **Runtime wrapper**: `vmRunShim` in `/lib/flake/shared.nix` is a script that collects SSH keys, validates them, writes them to `$XDG_STATE_HOME/vm/keys/$TARGET_HOST/authorized_keys`, and defers to `nix run` for the actual VM launch.
- **Testing**: CI runs `cargo fmt --check`, `cargo test --workspace` in a dev shell (`.github/workflows/checks.yml`). Run locally: `nix develop .#vm` then `cargo test --workspace`.
- **Important**: The VM CLI flake is a separate local flake input (`inputs.vm = { url = "./tools/vm"; ... }`). Changes to the VM crate structure (adding/removing crates) must be reflected in the workspace `Cargo.toml`.

### Modifying the MCP integration
- `/opencode.json` configures the remote MCP server URL (`http://localhost:8765/mcp`)
- The VM tool's `vm-mcp` crate serves MCP at this endpoint
- Rebuilding the VM flake after MCP changes: `nix build .#vm`
