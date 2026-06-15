#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SYSTEMD_DIR="$HOME/.config/systemd/user"
VM_SERVICE_DIR="$PROJECT_DIR/tools/vm-service"
VM_CLI_LINK="$PROJECT_DIR/.vm-cli"
VM_BIN="$VM_CLI_LINK/bin/vm"
LOCAL_BIN="$HOME/.local/bin/vm"
PERSONAL_NIX="$PROJECT_DIR/hosts/personal/default.nix"
VM_SSH_PORT="${VM_SSH_PORT:-2222}"
VM_SSH_USER="${VM_SSH_USER:-joao}"
SSH_IDENTITY="$HOME/.ssh/id_ed25519"
VM_SSH_KEYS_CHANGED=false

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
require_cmd python3 "Install Python 3 (used to sync VM SSH authorized keys)"
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

collect_ssh_pubkeys() {
  local keyfile line
  local -a pubkeys=()

  shopt -s nullglob
  for keyfile in "$HOME/.ssh"/*.pub; do
    line=$(grep -E '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256) ' "$keyfile" | head -1 || true)
    if [[ -n "$line" ]]; then
      pubkeys+=("$line")
    fi
  done
  shopt -u nullglob

  if [[ ${#pubkeys[@]} -eq 0 ]]; then
    echo "Error: No SSH public keys found in ~/.ssh/*.pub" >&2
    echo "Generate one with: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519" >&2
    exit 1
  fi

  printf '%s\n' "${pubkeys[@]}"
}

pubkey_material() {
  awk '{print $1 " " $2}'
}

config_authorized_key_material() {
  grep -E '^\s+"ssh-' "$PERSONAL_NIX" | sed -E 's/^[[:space:]]+"([^"]+)".*/\1/' | pubkey_material | sort -u
}

host_authorized_key_material() {
  collect_ssh_pubkeys | pubkey_material | sort -u
}

authorized_keys_match_config() {
  local config_keys host_keys
  config_keys=$(config_authorized_key_material)
  host_keys=$(host_authorized_key_material)
  [[ "$config_keys" == "$host_keys" ]]
}

update_authorized_keys_in_config() {
  local -a pubkeys=()
  local nix_file="$PERSONAL_NIX"
  mapfile -t pubkeys < <(collect_ssh_pubkeys)

  python3 - "$nix_file" "${pubkeys[@]}" <<'PY'
import re
import sys

nix_file = sys.argv[1]
keys = sys.argv[2:]
content = open(nix_file, encoding="utf-8").read()
keys_block = "authorizedKeys = [\n" + "\n".join(f'        "{key}"' for key in keys) + "\n      ];"
updated, count = re.subn(
    r"authorizedKeys = \[.*?\];",
    keys_block,
    content,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    sys.exit("Could not update authorizedKeys in hosts/personal/default.nix")
with open(nix_file, "w", encoding="utf-8") as handle:
    handle.write(updated)
PY
  VM_SSH_KEYS_CHANGED=true
}

ensure_ssh_identity() {
  if [[ -f "$SSH_IDENTITY" ]]; then
    return
  fi

  local candidate
  for candidate in personal_key id_rsa; do
    if [[ -f "$HOME/.ssh/$candidate" ]]; then
      echo "  Linking $SSH_IDENTITY -> $candidate"
      ln -sf "$candidate" "$SSH_IDENTITY"
      return
    fi
  done

  echo "Error: No SSH private key found for VM access." >&2
  echo "Expected $SSH_IDENTITY or ~/.ssh/{personal_key,id_rsa}." >&2
  exit 1
}

clean_vm_known_host() {
  local known_hosts="$HOME/.ssh/known_hosts"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  if [[ -f "$known_hosts" ]] && ssh-keygen -F "[localhost]:${VM_SSH_PORT}" -f "$known_hosts" >/dev/null 2>&1; then
    echo "  Removing stale [localhost]:${VM_SSH_PORT} host key from known_hosts"
    ssh-keygen -f "$known_hosts" -R "[localhost]:${VM_SSH_PORT}" >/dev/null
  fi
}

setup_vm_ssh() {
  echo "==> Configuring SSH for VM access..."

  ensure_ssh_identity
  clean_vm_known_host

  if authorized_keys_match_config; then
    echo "  authorizedKeys already match ~/.ssh/*.pub"
    return
  fi

  echo "  Syncing authorizedKeys in hosts/personal/default.nix from ~/.ssh/*.pub"
  update_authorized_keys_in_config
}

ssh_vm_probe() {
  ssh \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o IdentitiesOnly=yes \
    -o ConnectTimeout=5 \
    -i "$SSH_IDENTITY" \
    -p "$VM_SSH_PORT" \
    "${VM_SSH_USER}@localhost" \
    true
}

verify_vm_ssh() {
  if ! systemctl --user is-active --quiet vm 2>/dev/null; then
    echo "==> Skipping SSH verification (VM not running)"
    return
  fi

  echo "==> Verifying SSH to VM..."
  if ssh_vm_probe; then
    echo "  SSH OK (port ${VM_SSH_PORT})"
    return
  fi

  echo "Error: VM is running but SSH authentication failed on port ${VM_SSH_PORT}." >&2
  echo "Try: vm restart" >&2
  exit 1
}

restart_vm_if_needed() {
  if [[ "$VM_SSH_KEYS_CHANGED" != true ]]; then
    return
  fi

  if ! systemctl --user is-active --quiet vm 2>/dev/null; then
    return
  fi

  echo "==> Restarting VM (authorizedKeys changed)..."
  systemctl --user restart vm
  clean_vm_known_host

  echo "==> Waiting for SSH after VM restart..."
  local i
  for i in $(seq 1 60); do
    if ssh_vm_probe; then
      echo "  VM is ready (SSH on port ${VM_SSH_PORT})"
      return
    fi
    if (( i % 10 == 0 || i == 1 )); then
      echo "  ${i}s..."
    fi
    sleep 1
  done

  echo "Error: VM restarted but SSH is not responding after 60s." >&2
  exit 1
}

build_vm_image() {
  if [[ "$SKIP_VM_BUILD" == true ]]; then
    echo "==> Skipping VM image build (--skip-vm-build)"
    return
  fi

  if [[ -x "$PROJECT_DIR/result/bin/run-personal-vm" && "$VM_SSH_KEYS_CHANGED" != true ]]; then
    echo "==> VM image already built at result/bin/run-personal-vm"
    return
  fi

  if [[ "$VM_SSH_KEYS_CHANGED" == true ]]; then
    echo "==> Rebuilding VM image (authorizedKeys changed)..."
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

ensure_virtiofsd() {
  if [ -x "/run/current-system/sw/bin/virtiofsd" ]; then
    echo "/run/current-system/sw/bin/virtiofsd"
    return
  fi

  echo "==> virtiofsd not in current system profile; building fallback..." >&2
  (
    cd "$PROJECT_DIR"
    nix build nixpkgs#virtiofsd --out-link .virtiofsd
  )
  echo "$PROJECT_DIR/.virtiofsd/bin/virtiofsd"
}

install_systemd_services() {
  echo "==> Installing systemd user services..."
  mkdir -p "$SYSTEMD_DIR"

  cp "$VM_SERVICE_DIR/vm.service" "$SYSTEMD_DIR/"
  cp "$VM_SERVICE_DIR/vm-mcp.service" "$SYSTEMD_DIR/"
  cp "$VM_SERVICE_DIR/virtiofsd.service" "$SYSTEMD_DIR/"

  sed -i "s|%h/proj/angst|$PROJECT_DIR|g" "$SYSTEMD_DIR/vm.service"
  sed -i "s|%h/proj/angst|$PROJECT_DIR|g" "$SYSTEMD_DIR/vm-mcp.service"
  sed -i "s|%h/proj/angst|$PROJECT_DIR|g" "$SYSTEMD_DIR/virtiofsd.service"

  local virtiofsd_bin
  virtiofsd_bin=$(ensure_virtiofsd)
  sed -i "s|/run/current-system/sw/bin/virtiofsd|$virtiofsd_bin|g" "$SYSTEMD_DIR/virtiofsd.service"

  systemctl --user daemon-reload
}

setup_vm_ssh
build_vm_image
build_vm_cli
install_vm_on_path
install_mcp_deps
install_systemd_services

restart_vm_if_needed

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
  verify_vm_ssh
else
  verify_vm_ssh
fi
