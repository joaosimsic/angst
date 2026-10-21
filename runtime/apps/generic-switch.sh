#!/usr/bin/env bash
set -euo pipefail

export NIX_CONFIG='experimental-features = nix-command flakes'

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: generic-switch [nixos-rebuild options]

Switches the running generic host to the current flake state after a
confirmation prompt. This does not create or delete partitions. It only
changes the active NixOS generation and mounts from storage.nix.

Run generic-provision first if the system is not already booted from @root.
EOF
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
esac

if REPO_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  REPO_DIR="$PWD"
fi

cd "$REPO_DIR"

[ -f flake.nix ] || die "not in the angst repository (flake.nix not found)"
[ -f hosts/personal/generic/default.nix ] || die "hosts/personal/generic/default.nix not found"
[ -f hosts/personal/generic/storage.nix ] || die "hosts/personal/generic/storage.nix not found"

HOST_NAME="$(cat /etc/hostname 2>/dev/null || true)"
[ "$HOST_NAME" = "generic" ] || die "generic-switch must run on hostname generic (found: ${HOST_NAME:-unknown})"

ROOT_FSROOT="$(findmnt -n -o FSROOT / || true)"
case "$ROOT_FSROOT" in
  *@root*) ;;
  *)
    die "the current root is not @root; run generic-provision and reboot first"
    ;;
esac

printf '==> Current disk layout\n'
lsblk -f
printf '\n==> Current mounts\n'
findmnt / /boot /home /nix || true
printf '\nWARNING: switching the generic host changes the active system and mounts.\n'
printf '         storage.nix must describe the actual @root/@home/@nix devices.\n'
printf '         Generic-provision never rewrites the partition table; this switch does not either.\n'
printf '\nType generic to continue: '
read -r answer
[ "$answer" = "generic" ] || die "aborted"

NIXOS_REBUILD="$(command -v nixos-rebuild)"
SUDO="$(command -v sudo || true)"

if [ "$(id -u)" -eq 0 ]; then
  exec "$NIXOS_REBUILD" switch --flake "path:$REPO_DIR#generic" "$@"
fi

[ -n "$SUDO" ] || die "sudo not found and current user is not root"
exec "$SUDO" env NIX_CONFIG="$NIX_CONFIG" "$NIXOS_REBUILD" switch --flake "path:$REPO_DIR#generic" "$@"
