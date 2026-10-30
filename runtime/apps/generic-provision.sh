#!/usr/bin/env bash
set -euo pipefail

export NIX_CONFIG='experimental-features = nix-command flakes'

HOST_DIR="hosts/personal/generic"
STORAGE="$HOST_DIR/storage.nix"
TOP="/run/angst-btrfs"
DRY_RUN=0
FORCE_STORAGE=0
DAEMON_STOPPED=0
MOUNTED=0

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

usage() {
  cat <<'EOF'
Usage: generic-provision [options]

Creates @root/@home/@nix/@state inside the btrfs partition installed by
Calamares, writes hosts/personal/generic/storage.nix, and prepares a
systemd-boot entry for the generic host.

This script never creates, deletes, or resizes partitions and never runs
disko. It only creates btrfs subvolumes and copies data on the existing
btrfs filesystem. The GPT, ESP, and Windows partitions are not modified.

If no btrfs partition is found, or if / is not btrfs, the script warns and
skips provisioning without changing anything.

Options:
  --dry-run                     Print the plan without creating subvolumes.
  --force-overwrite-storage     Overwrite an existing generated storage.nix.
  -h, --help                    Show this help.
EOF
}

cleanup() {
  local status=$?
  trap - EXIT
  if [ "$DAEMON_STOPPED" -eq 1 ]; then
    systemctl start nix-daemon.socket nix-daemon.service >/dev/null 2>&1 || true
  fi
  if [ "$MOUNTED" -eq 1 ] && mountpoint -q "$TOP"; then
    umount "$TOP" >/dev/null 2>&1 || true
  fi
  exit "$status"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  --dry-run)
    DRY_RUN=1
    shift
    ;;
  --force-overwrite-storage)
    FORCE_STORAGE=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    die "unknown option: $1 (try --help)"
    ;;
  esac
done

if REPO_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  REPO_DIR="$PWD"
fi

cd "$REPO_DIR"

[ -f flake.nix ] || die "not in the angst repository (flake.nix not found)"
[ -f "$HOST_DIR/default.nix" ] || die "$HOST_DIR/default.nix not found"

ROOT_SOURCE="$(findmnt -n -o SOURCE / || true)"
ROOT_FSTYPE="$(findmnt -n -o FSTYPE / || true)"
BTRFS_DEVICES="$(lsblk -nlo PATH,FSTYPE 2>/dev/null | awk '$2 == "btrfs" { print $1 }' || true)"

if [ -z "$BTRFS_DEVICES" ]; then
  warn "no btrfs partition found; skipping btrfs provisioning; no disk changes made"
  exit 0
fi

if [ "$ROOT_FSTYPE" != "btrfs" ]; then
  warn "/ is not btrfs (found: ${ROOT_FSTYPE:-unknown}); skipping btrfs provisioning; no disk changes made"
  exit 0
fi

[ "$(id -u)" -eq 0 ] || die "must run as root (sudo nix run .#generic-provision)"

[ -d /sys/firmware/efi ] || die "not booted in UEFI mode"
[ -n "$ROOT_SOURCE" ] || die "could not resolve the root device"

case "$ROOT_SOURCE" in
/dev/mapper/*)
  die "encrypted root detected; generic-provision currently supports plain btrfs only"
  ;;
esac

ROOT_DEV="$(readlink -f "$ROOT_SOURCE")"
[ -b "$ROOT_DEV" ] || die "root source is not a block device: $ROOT_DEV"

ESP_SOURCE="$(findmnt -n -o SOURCE /boot || true)"
ESP_FSTYPE="$(findmnt -n -o FSTYPE /boot || true)"
[ -n "$ESP_SOURCE" ] || die "/boot is not mounted"
[ "$ESP_FSTYPE" = "vfat" ] || die "/boot is not vfat (found: ${ESP_FSTYPE:-unknown})"

if [ -f "$STORAGE" ] && ! grep -q "GENERIC-PROVISION-PLACEHOLDER" "$STORAGE" && [ "$FORCE_STORAGE" -ne 1 ]; then
  die "$STORAGE already exists and is not a placeholder; pass --force-overwrite-storage to replace it"
fi

trap cleanup EXIT

mkdir -p "$TOP"
mount -o subvolid=5 "$ROOT_DEV" "$TOP"
MOUNTED=1

ROOT_FSROOT="$(findmnt -n -o FSROOT / || true)"
MIGRATED=0
case "$ROOT_FSROOT" in
*@root*)
  MIGRATED=1
  ;;
esac

if [ "$MIGRATED" -eq 0 ] && btrfs subvolume show "$TOP/@root" >/dev/null 2>&1; then
  die "@root already exists but is not the current root; refusing to overwrite it"
fi

printf '==> Current disk layout\n'
lsblk -f
printf '\n==> Current mounts\n'
findmnt / /boot /home /nix || true
printf '\n==> Existing btrfs subvolumes\n'
btrfs subvolume list "$TOP" || true
printf '\n==> Plan\n'
printf '  root device: %s\n' "$ROOT_DEV"
if [ "$MIGRATED" -eq 1 ]; then
  printf '  @root: reused (current root is already @root)\n'
else
  printf '  @root: snapshot of /\n'
fi
printf '  @home: create if missing and copy /home\n'
printf '  @nix: create if missing and copy /nix\n'
printf '  @state: create if missing (not mounted by generic host)\n'
printf '  storage: %s\n' "$STORAGE"
printf '  no partition table, ESP, or Windows changes\n'

if [ "$DRY_RUN" -eq 1 ]; then
  printf '\n==> Dry run complete; no changes made\n'
  exit 0
fi

printf '\nType MIGRATE to create the subvolumes and prepare the generic boot entry: '
read -r answer
[ "$answer" = "MIGRATE" ] || die "aborted"

if [ "$MIGRATED" -eq 0 ]; then
  printf '==> Snapshotting / into @root\n'
  btrfs subvolume snapshot / "$TOP/@root" || die "could not snapshot / into @root; no boot entry was written"
else
  printf '==> Reusing existing @root\n'
fi

for subvol in @home @nix @state; do
  if ! btrfs subvolume show "$TOP/$subvol" >/dev/null 2>&1; then
    printf '==> Creating %s\n' "$subvol"
    btrfs subvolume create "$TOP/$subvol"
  else
    printf '==> Reusing %s\n' "$subvol"
  fi
done

if [ -z "$(find "$TOP/@home" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
  printf '==> Copying /home into @home\n'
  cp -a --reflink=auto /home/. "$TOP/@home/"
else
  printf '==> @home is not empty; leaving it unchanged\n'
fi

ROOT_UUID="$(blkid -s UUID -o value "$ROOT_DEV" || true)"
[ -n "$ROOT_UUID" ] || die "could not read the btrfs UUID"

ROOT_LABEL="$(blkid -s LABEL -o value "$ROOT_DEV" || true)"
if [ "$ROOT_LABEL" = "nixos" ]; then
  ROOT_DEVICE="/dev/disk/by-label/nixos"
elif btrfs filesystem label "$ROOT_DEV" nixos >/dev/null 2>&1; then
  ROOT_DEVICE="/dev/disk/by-label/nixos"
else
  ROOT_DEVICE="/dev/disk/by-uuid/$ROOT_UUID"
fi

ESP_DEV="$(readlink -f "$ESP_SOURCE")"
ESP_UUID="$(blkid -s UUID -o value "$ESP_DEV" || true)"
ESP_PARTLABEL="$(blkid -s PARTLABEL -o value "$ESP_DEV" || true)"
[ -n "$ESP_UUID" ] || die "could not read the ESP UUID"

if [ -n "$ESP_PARTLABEL" ]; then
  ESP_DEVICE="/dev/disk/by-partlabel/$ESP_PARTLABEL"
else
  ESP_DEVICE="/dev/disk/by-uuid/$ESP_UUID"
fi

STORAGE_MATCHES=0
if [ -f "$STORAGE" ] &&
  grep -Fq "device = \"$ROOT_DEVICE\";" "$STORAGE" &&
  grep -Fq "device = \"$ESP_DEVICE\";" "$STORAGE" &&
  grep -Fq 'subvol=@root' "$STORAGE" &&
  grep -Fq 'subvol=@home' "$STORAGE" &&
  grep -Fq 'subvol=@nix' "$STORAGE"; then
  STORAGE_MATCHES=1
fi

if [ "$STORAGE_MATCHES" -eq 1 ] && [ "$FORCE_STORAGE" -ne 1 ]; then
  printf '==> %s already matches; leaving unchanged\n' "$STORAGE"
else
  printf '==> Writing %s\n' "$STORAGE"
  STORAGE_OWNER="$(stat -c '%u:%g' "$HOST_DIR/default.nix")"
  STORAGE_TMP="$(mktemp "${STORAGE}.XXXXXX")"
  cat >"$STORAGE_TMP" <<EOF
# GENERATED BY generic-provision.
{ config, ... }:
{
  assertions = [
    {
      assertion = config.networking.hostName == "generic";
      message = "hosts/personal/generic/storage.nix may only be imported by the generic host";
    }
  ];

  fileSystems = {
    "/" = {
      device = "$ROOT_DEVICE";
      fsType = "btrfs";
      options = [ "compress=zstd" "noatime" "subvol=@root" ];
    };

    "/home" = {
      device = "$ROOT_DEVICE";
      fsType = "btrfs";
      options = [ "compress=zstd" "noatime" "subvol=@home" ];
      neededForBoot = true;
    };

    "/nix" = {
      device = "$ROOT_DEVICE";
      fsType = "btrfs";
      options = [ "compress=zstd" "noatime" "subvol=@nix" ];
      neededForBoot = true;
    };

    "/boot" = {
      device = "$ESP_DEVICE";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  };

  swapDevices = [ ];
}
EOF
  chown "$STORAGE_OWNER" "$STORAGE_TMP"
  mv "$STORAGE_TMP" "$STORAGE"
fi

printf '==> Building generic system\n'
nix build --no-link "path:$REPO_DIR#nixosConfigurations.generic.config.system.build.toplevel"

printf '==> Stopping nix-daemon and copying /nix into @nix\n'
if systemctl is-active --quiet nix-daemon.socket || systemctl is-active --quiet nix-daemon.service; then
  systemctl stop nix-daemon.socket nix-daemon.service || true
  DAEMON_STOPPED=1
fi
rsync -aHAX --exclude=/var/nix/daemon-socket /nix/ "$TOP/@nix/"
if [ "$DAEMON_STOPPED" -eq 1 ]; then
  systemctl start nix-daemon.socket nix-daemon.service >/dev/null 2>&1 || true
  DAEMON_STOPPED=0
fi

printf '==> Writing generic systemd-boot entry\n'
nixos-rebuild boot --flake "path:$REPO_DIR#generic"

printf '==> Final /nix sync into @nix\n'
if systemctl is-active --quiet nix-daemon.socket || systemctl is-active --quiet nix-daemon.service; then
  systemctl stop nix-daemon.socket nix-daemon.service || true
  DAEMON_STOPPED=1
fi
rsync -aHAX --exclude=/var/nix/daemon-socket /nix/ "$TOP/@nix/"
if [ "$DAEMON_STOPPED" -eq 1 ]; then
  systemctl start nix-daemon.socket nix-daemon.service >/dev/null 2>&1 || true
  DAEMON_STOPPED=0
fi

[ -d "$TOP/@root/etc" ] || die "@root does not look like a root filesystem"
[ -d "$TOP/@home" ] || die "@home is missing"
[ -d "$TOP/@nix/store" ] || die "@nix/store is missing"
[ -d "$TOP/@nix/var/nix/db" ] || die "@nix/var/nix/db is missing"

sync
printf '\n==> Done. Reboot and select the generic systemd-boot entry.\n'
printf '    The old top-level entry remains as fallback.\n'
printf '    Do not delete old home/nix subvolumes until generic boots and data is verified.\n'
