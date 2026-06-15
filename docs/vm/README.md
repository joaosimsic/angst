# VM CLI & MCP Service

Rust CLI for managing the NixOS VM, plus optional MCP server for AI agents.

All commands below run on the **host** machine, not inside the VM.

## Quick start (host dev)

```bash
./scripts/setup-tools.sh
vm start
```

Run on your development host to build the NixOS VM image, install `vm` on `~/.local/bin`, install vm-mcp dependencies, and register systemd user services. The disk image `personal.qcow2` is created on the first `vm start`.

Re-run after pulling changes without rebuilding the VM image:

```bash
./scripts/setup-tools.sh --skip-vm-build
```

## Prerequisites

- **Nix** (with flakes enabled) — to build the VM image and vm-cli
- **QEMU** — runs the VM (bundled in the NixOS VM build output)
- **Bun** — JavaScript runtime for the MCP server (optional; `nix run nixpkgs#bun` is used as fallback)
- **OpenSSH client** (`ssh`, `scp`) — used by CLI and MCP tools for file transfer and commands
- **SSH agent** running (`SSH_AUTH_SOCK` set) — used by the MCP server to authenticate to the VM
- **Rust** — optional; only needed if developing vm-cli locally (`cargo build --release`)

## Build the CLI manually

Setup installs vm-cli via Nix. For local development:

```bash
cd tools/vm-cli
cargo build --release
```

Binary is at `tools/vm-cli/target/release/vm`.

## VM Management

```bash
vm start          # Start VM and wait for SSH
vm stop           # Stop VM
vm restart        # Restart VM and wait for SSH
vm status         # Check if VM is running (SSH reachable)
vm logs           # Tail VM journalctl logs (default 50 lines)
vm logs -l 200    # Tail 200 lines
```

## SSH & File Transfer

```bash
vm ssh            # SSH into the VM
vm ssh "ls -la"   # Run a command and exit
vm exec <cmd>     # Run a command inside the VM via SSH
vm copy-to <src> [dest]     # Copy file from host to VM
vm copy-from <src> [dest]   # Copy file from VM to host
```

## MCP Server (for AI agents)

The MCP server is optional and only needed for AI agent integration.

```bash
vm mcp start      # Start MCP server
vm mcp stop       # Stop MCP server
vm mcp restart    # Restart MCP server
vm mcp status     # Check MCP server status
vm mcp logs       # Tail MCP server logs
```

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VM_SSH_PORT` | `2222` | SSH port forwarded from VM |
| `VM_SSH_USER` | `joao` | SSH user for VM |
| `VM_CLI_PATH` | `vm` (in PATH) | Path to the `vm` binary (used by MCP server) |

## Systemd Services (optional)

The systemd services are **not enabled by default**. Use the CLI to manage the VM.

If you want systemd integration without rebuilding the VM image:

```bash
bash tools/vm-service/setup.sh
```

This is equivalent to `./scripts/setup-tools.sh --skip-vm-build`.

This installs the services but does **not** enable them at startup. Start manually:

```bash
vm start
vm mcp start
```

## Architecture

```
Host
├── vm CLI (Rust)
│   ├── systemctl --user start/stop/restart vm
│   ├── ssh/scp for VM access
│   └── journalctl for logs
└── vm-mcp.service (optional, for AI agents)
    └── MCP HTTP server on :8765
        └── Connects to VM via SSH (localhost:2222, user joao, SSH agent auth)
```

### MCP Tools

| Tool | Description |
|------|-------------|
| `vm_exec` | Execute a command inside the VM via SSH |
| `vm_status` | Check if the VM is reachable |
| `vm_restart` | Restart the VM via the CLI |
| `vm_logs` | Fetch journalctl logs from inside the VM |
| `vm_copy_to` | Copy a file from host to VM via scp |
| `vm_copy_from` | Copy a file from VM to host via scp |
