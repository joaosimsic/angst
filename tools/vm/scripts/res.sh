TARGET_HOST="${NIX_TARGET_HOST:-}"
[ -z "$TARGET_HOST" ] && TARGET_HOST="${NIX_DEFAULT_TARGET_HOST:-}"
[ -z "$TARGET_HOST" ] && TARGET_HOST="${ANGST_HOST:-}"
TARGET_HOST="${TARGET_HOST:-@defaultHost@}"

FLAKE_DIR="${ANGST_REPO:-$(pwd)}"
SSH_PORT="${VM_SSH_PORT:-2222}"

SSH_USER="${VM_SSH_USER:-}"
if [ -z "$SSH_USER" ] && [ -f "$FLAKE_DIR/hosts/$TARGET_HOST/default.nix" ]; then
    SSH_USER="$(nix eval --file "$FLAKE_DIR/hosts/$TARGET_HOST/default.nix" --raw --apply "x: x.username or null" 2>/dev/null)"
fi
SSH_USER="${SSH_USER:-user}"

export ANGST_USERNAME="$SSH_USER"
if [ -f "$FLAKE_DIR/hosts/$TARGET_HOST/default.nix" ]; then
    export ANGST_THEME="$(nix eval --file "$FLAKE_DIR/hosts/$TARGET_HOST/default.nix" --raw --apply "x: x.theme or \"monochrome\"" 2>/dev/null)"
fi

echo "Building VM for host '$TARGET_HOST' (user: $SSH_USER)..."
git -C "$FLAKE_DIR" update-index -q --refresh 2>/dev/null || true
if ! nix build ".#nixosConfigurations.${TARGET_HOST}.config.system.build.vm" --impure --refresh --no-write-lock-file 2>&1; then
    echo "Error: VM build failed"
    exit 1
fi

RUNNER="result/bin/run-$TARGET_HOST-vm"
if [ ! -f "$RUNNER" ]; then
    RUNNER="result/bin/run-nixos-vm"
fi
if [ ! -f "$RUNNER" ]; then
    echo "Error: VM runner not found at result/bin/run-$TARGET_HOST-vm or result/bin/run-nixos-vm"
    exit 1
fi

echo "Starting VM..."
pkill -f "run-$TARGET_HOST-vm" 2>/dev/null || true
pkill -f "qemu-system.*qcow2" 2>/dev/null || true
rm -f "$HOME/.local/state/vm/vm.json" "$HOME/.local/state/vm/vm-mcp.json" 2>/dev/null || true
sleep 2

KEY_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/vm/keys/$TARGET_HOST"
KEY_FILE="$KEY_DIR/authorized_keys"

collect_ssh_keys

export ANGST_REPO="$PWD"
export QEMU_OPTS="-display none -vga none"
export SHARED_DIR="$KEY_DIR"
export QEMU_NET_OPTS="hostfwd=tcp::2222-:22"
nohup "$RUNNER" >/tmp/vm-boot.log 2>&1 &

SSH_OPTS="-p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=1 -o LogLevel=ERROR -o ForwardAgent=yes"
echo "Waiting for VM to be ready..."
for i in $(seq 1 120); do
    if ssh $SSH_OPTS "$SSH_USER@localhost" "echo ready" 2>/dev/null; then
        echo "VM is ready!"
        break
    fi
    sleep 1
done

echo "Syncing declared projects..."
ssh $SSH_OPTS "$SSH_USER@localhost" 'bash -lc "angst-projects-sync sync"' 2>&1 || true

exec ssh $SSH_OPTS "$SSH_USER@localhost"
