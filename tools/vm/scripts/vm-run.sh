TARGET_HOST="${NIX_TARGET_HOST:-}"
[ -z "$TARGET_HOST" ] && TARGET_HOST="${NIX_DEFAULT_TARGET_HOST:-}"
[ -z "$TARGET_HOST" ] && TARGET_HOST="${ANGST_HOST:-}"
TARGET_HOST="${TARGET_HOST:-@defaultHost@}"

KEY_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/vm/keys/$TARGET_HOST"
KEY_FILE="$KEY_DIR/authorized_keys"

NEW_ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--headless" ]; then
        export QEMU_OPTS="${QEMU_OPTS:-} -display none"
    else
        NEW_ARGS+=("$arg")
    fi
done

collect_ssh_keys

RUNNER="result/bin/run-${TARGET_HOST}-vm"
if [ ! -f "$RUNNER" ]; then
    RUNNER="result/bin/run-nixos-vm"
fi
if [ ! -f "$RUNNER" ]; then
    echo "Error: VM runner not found at result/bin/run-${TARGET_HOST}-vm or result/bin/run-nixos-vm. Build the VM first (e.g. 'nix build .#nixosConfigurations.${TARGET_HOST}.config.system.build.vm')."
    exit 1
fi

export ANGST_REPO="$PWD"
export QEMU_NET_OPTS="hostfwd=tcp::2222-:22"
export NIX_DISK_IMAGE="${NIX_DISK_IMAGE:-$PWD/$TARGET_HOST.qcow2}"
export SHARED_DIR="$KEY_DIR"

exec "$RUNNER" "${NEW_ARGS[@]}"
