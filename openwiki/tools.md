# Tools

angst ships three CLI tools and an OpenCode MCP integration for VM management.

## angst CLI — Hot-Reload Renderer

A shell script (`/lib/flake/shared.nix` → `angst`) for rendering theme-aware domain configs without a full Nix rebuild.

### Commands

```bash
# Render all domain configs to ~/.config/
angst render

# Watch for file changes and re-render automatically
angst watch
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

### How it works

1. Calls `nix eval` to compute rendered configs from all domain `render.nix` files
2. Writes the output files to `~/.config/<app>/` paths
3. Optionally triggers `i3-msg reload` for immediate UI update

The `watch` command uses `watchexec` to monitor the repository for changes and re-render automatically.

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

1. Resolves the user's preferred shell from `SHELL_ENABLED_SHELLS` env var
2. Symlinks Tree-sitter parsers and queries into `~/.local/share/tree-sitter/`
3. Prepends a Nix-provided `PATH` (baked in at build time via `SHELL_SAFE_PATH`/`SHELL_DEV_PATH`)
4. `exec()`s the shell with `IN_NIX_SHELL`, `SHELL_MODE`, and `ORIGINAL_SHELL` env vars

The binary is built by Nix and wrapped with store paths, so no `nix` invocation is needed at runtime.

### Use Cases

- **Safe mode**: Tree-sitter parsers work on hosts with older glibc (e.g., Debian 12 with glibc 2.36) because neovim and parsers both link against Nix's glibc
- **Dev mode**: Full development environment with Rust toolchain, QEMU, and angst/VM CLIs

## VM CLI — QEMU Virtual Machine Manager

A Rust CLI + MCP server (`/tools/vm/`) for managing NixOS development VMs.

### Architecture

Three crates in a Cargo workspace:
- **`vm-core`** — Core types and VM lifecycle logic. Provides `SshEngine` (libssh2 wrapper), `VmConfig` (env-var-based), `VmProcessController` (background process lifecycle with PID state files in `~/.local/state/vm/`).
- **`vm-cli`** — CLI interface with clap-derived subcommands: `start`, `stop`, `restart`, `status`, `ssh`, `exec`, `copy-to`, `copy-from`, `health`, `logs`, and `mcp` (with its own subcommands).
- **`vm-mcp`** — Axum HTTP server serving MCP (Model Context Protocol) on port 8765, exposing `vm_exec`, `vm_status`, and `vm_restart` tools for AI agent integration.

### CLI Commands

```bash
# Build VM outputs from the flake
nix build .#vm

# Start the VM (builds if needed, polls SSH up to 120s)
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

# Run headless (no QEMU window)
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
- Source: `/lib/flake/shared.nix` (lines ~30–210, the `angstCli` shell script)
- The `render` command calls `nix eval --impure "$repo_root#lib.renderDomainOutputsFor"` — any change to the `renderDomainOutputsFor` function in `/lib/flake/default.nix` affects the CLI output
- The `watch` command uses `watchexec` — ensure it's available as a runtime input (`pkgs.watchexec` in `angstCli` definition)
- Environment variable fallback chain: `$ANGST_REPO` → `git rev-parse` → `pwd`

### Modifying the shell CLI
- Source: `/tools/shell/` Rust project (3 source files)
- **`commands.rs`** — CLI argument definition (clap derive). Add new subcommands here.
- **`runner.rs`** — Shell environment setup. Key env vars baked in at build time via `makeWrapper`:
  - `SHELL_SAFE_PATH`, `SHELL_DEV_PATH` — PATH overrides (set in `shared.nix`)
  - `SHELL_TS_PARSERS`, `SHELL_TS_QUERIES` — Tree-sitter paths
  - `SHELL_DEV_ENTRY` — Dev hook entry script
  - `SHELL_ENABLED_SHELLS` — Colon-separated shell paths for host-specific shells
- **Build**: Built by `tools/shell/flake.nix` as a local flake input. The wrapper (`shellWrapped`) is constructed in `/lib/flake/shared.nix`
- **Testing**: Run `cargo test` from `/tools/shell/`

### Modifying the VM CLI
- Source: `/tools/vm/` Cargo workspace (3 crates: `vm-core`, `vm-cli`, `vm-mcp`)
- **`vm-core`** — Core VM lifecycle logic. Changes here affect all consumers (CLI and MCP).
- **`vm-cli`** — CLI interface. Add new commands here.
- **`vm-mcp`** — MCP server for AI agent integration. The MCP endpoint is configured in `/opencode.json` (port 8765).
- **Build**: Built by `tools/vm/flake.nix`. The flake constructs `allHostVms` by mapping over NixOS configurations.
- **Runtime wrapper**: `vmRunShim` in `/lib/flake/shared.nix` is a lightweight script that defers to `nix run` to avoid evaluation recursion.
- **Testing**: CI runs `cargo fmt --check`, `cargo test --workspace` in a dev shell (`.github/workflows/checks.yml`). Run locally: `nix develop .#vm` then `cargo test --workspace`.
- **Important**: The VM CLI flake is a separate local flake input (`inputs.vm = { url = "./tools/vm"; ... }`). Changes to the VM crate structure (adding/removing crates) must be reflected in the workspace `Cargo.toml`.

### Modifying the MCP integration
- `/opencode.json` configures the remote MCP server URL (`http://localhost:8765/mcp`)
- The VM tool's `vm-mcp` crate serves MCP at this endpoint
- Rebuilding the VM flake after MCP changes: `nix build .#vm`
