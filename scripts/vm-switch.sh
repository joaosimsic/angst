#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VM_USER="${VM_SSH_USER:-joao}"
VM_PORT="${VM_SSH_PORT:-2222}"
VM_IDENTITY="${VM_SSH_IDENTITY:-$HOME/.ssh/id_ed25519}"
DISK_IMAGE="${NIX_DISK_IMAGE:-$PROJECT_DIR/personal.qcow2}"

SSH_OPTS=(
  -p "$VM_PORT"
  -i "$VM_IDENTITY"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
)

if ! ssh "${SSH_OPTS[@]}" -o ConnectTimeout=3 "${VM_USER}@localhost" true 2>/dev/null; then
  echo "==> VM is not reachable on port ${VM_PORT}." >&2
  echo "    If a previous switch removed sshd, reset the disk and start fresh:" >&2
  echo "      vm stop && rm -f ${DISK_IMAGE} && vm start" >&2
  exit 1
fi

echo "==> Building VM system configuration on host..."
SYSTEM="$(
  nix build "${PROJECT_DIR}#nixosConfigurations.personal.config.specialisation.vm.configuration.system.build.toplevel" \
    --print-out-paths
)"

echo "==> Activating on VM via ${SYSTEM}..."
ssh -tt "${SSH_OPTS[@]}" "${VM_USER}@localhost" \
  "sudo ${SYSTEM}/bin/switch-to-configuration switch"
