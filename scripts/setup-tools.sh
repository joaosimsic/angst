#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SYSTEMD_DIR="$HOME/.config/systemd/user"
VM_SERVICE_DIR="$PROJECT_DIR/tools/vm-service"
VM_CLI_LINK="$PROJECT_DIR/.vm-cli"
VM_BIN="$VM_CLI_LINK/bin/vm"
LOCAL_BIN="$HOME/.local/bin/vm"

SKIP_VM_BUILD=false
SKIP_MCP=false
DO_START=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Bootstrap host dev tooling for the angst VM workflow.
Run on your development host — not on a bare-metal NixOS install.

Options:
  --skip-vm-build   Skip building the NixOS VM image (use when result/ already exists)
  --skip-mcp        Skip vm-mcp dependency install
  --start           Start the VM after setup completes
  -h, --help        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-vm-build) SKIP_VM_BUILD=true ;;
    --skip-mcp) SKIP_MCP=true ;;
    --start) DO_START=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

require_cmd() {
  local cmd="$1"
  local hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but not found." >&2
    echo "$hint" >&2
    exit 1
  fi
}

echo "==> Checking prerequisites..."

require_cmd nix "Install Nix with flakes enabled: https://nixos.org/download.html"
require_cmd ssh "Install OpenSSH client (ssh)"
require_cmd scp "Install OpenSSH client (scp)"
require_cmd systemctl "systemctl is required for VM service management"

if ! nix flake metadata "$PROJECT_DIR" >/dev/null 2>&1; then
  echo "Error: Nix flakes are not available or this is not a valid flake." >&2
  exit 1
fi

if ! systemctl --user show-environment >/dev/null 2>&1; then
  echo "Error: user systemd session is not available (systemctl --user failed)." >&2
  echo "Ensure you are logged into a desktop/session with user systemd running." >&2
  exit 1
fi

run_bun() {
  if command -v bun >/dev/null 2>&1; then
    bun "$@"
  else
    echo "  bun not found on PATH; using nix run nixpkgs#bun"
    nix run nixpkgs#bun -- "$@"
  fi
}

build_vm_image() {
  if [[ "$SKIP_VM_BUILD" == true ]]; then
    echo "==> Skipping VM image build (--skip-vm-build)"
    return
  fi

  if [[ -x "$PROJECT_DIR/result/bin/run-personal-vm" ]]; then
    echo "==> VM image already built at result/bin/run-personal-vm"
    return
  fi

  echo "==> Building NixOS VM image (this may take a while)..."
  (
    cd "$PROJECT_DIR"
    nix build .#nixosConfigurations.personal.config.system.build.vm -o result
  )
}

build_vm_cli() {
  echo "==> Building vm-cli via Nix..."
  (
    cd "$PROJECT_DIR"
    nix build .#vm-cli --out-link .vm-cli
  )
}

install_vm_on_path() {
  echo "==> Installing vm on PATH..."
  mkdir -p "$HOME/.local/bin"
  ln -sf "$VM_BIN" "$LOCAL_BIN"

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *)
      echo "Warning: ~/.local/bin is not in your PATH."
      echo "Add this to your shell profile:"
      echo '  export PATH="$HOME/.local/bin:$PATH"'
      ;;
  esac
}

install_mcp_deps() {
  if [[ "$SKIP_MCP" == true ]]; then
    echo "==> Skipping vm-mcp install (--skip-mcp)"
    return
  fi

  echo "==> Installing vm-mcp dependencies..."
  (
    cd "$PROJECT_DIR/tools/vm-mcp"
    run_bun install
  )
}

install_systemd_services() {
  echo "==> Installing systemd user services..."
  mkdir -p "$SYSTEMD_DIR"

  cp "$VM_SERVICE_DIR/vm.service" "$SYSTEMD_DIR/"
  cp "$VM_SERVICE_DIR/vm-mcp.service" "$SYSTEMD_DIR/"

  sed -i "s|%h/proj/angst|$PROJECT_DIR|g" "$SYSTEMD_DIR/vm.service"
  sed -i "s|%h/proj/angst|$PROJECT_DIR|g" "$SYSTEMD_DIR/vm-mcp.service"

  systemctl --user daemon-reload
}

build_vm_image
build_vm_cli
install_vm_on_path
install_mcp_deps
install_systemd_services

echo ""
echo "Host dev tooling setup complete! Services are installed but NOT enabled at startup."
echo ""
echo "Next steps:"
echo "  vm start     # start VM (creates personal.qcow2 on first run)"
echo "  vm status    # check VM status"
echo "  vm ssh       # SSH into the VM"
if [[ "$SKIP_MCP" == false ]]; then
  echo "  vm mcp start # start MCP server (optional)"
fi
echo ""
echo "Or use systemctl directly:"
echo "  systemctl --user start vm"
if [[ "$SKIP_MCP" == false ]]; then
  echo "  systemctl --user start vm-mcp"
fi

if [[ "$DO_START" == true ]]; then
  echo ""
  echo "==> Starting VM..."
  "$LOCAL_BIN" start
fi
