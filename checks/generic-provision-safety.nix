{
  pkgs,
}:

let
  provision = ../runtime/apps/generic-provision.sh;
  switch = ../runtime/apps/generic-switch.sh;
in
pkgs.runCommand "generic-provision-safety"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
  }
  ''
    set -euo pipefail

    echo "==> Checking generic-provision for forbidden disk commands"
    if grep -En '^[[:space:]]*(sudo[[:space:]]+)?(disko|sgdisk|sfdisk|parted|mkfs(\.[a-z0-9]+)?|wipefs)([[:space:]]|$)' ${provision}; then
      echo "generic-provision contains a forbidden partition/filesystem command" >&2
      exit 1
    fi

    echo "==> Checking no-btrfs branch is before mutation"
    warn_line=$(grep -n 'no btrfs partition found' ${provision} | head -n 1 | cut -d: -f1 || true)
    mount_line=$(grep -n 'mount -o subvolid=5' ${provision} | head -n 1 | cut -d: -f1 || true)
    test -n "$warn_line"
    test -n "$mount_line"
    test "$warn_line" -lt "$mount_line"

    echo "==> Checking dry-run exits before subvolume creation"
    dry_line=$(grep -n 'DRY_RUN" -eq 1' ${provision} | head -n 1 | cut -d: -f1 || true)
    snapshot_line=$(grep -n 'btrfs subvolume snapshot /' ${provision} | head -n 1 | cut -d: -f1 || true)
    test -n "$dry_line"
    test -n "$snapshot_line"
    test "$dry_line" -lt "$snapshot_line"

    echo "==> Checking generic-switch guards"
    grep -Fq 'generic-switch must run on hostname generic' ${switch}
    grep -Fq 'the current root is not @root' ${switch}
    grep -Fq 'Type generic to continue' ${switch}

    echo "==> Checking generic-provision does not claim partition mutation"
    grep -Fq 'no partition table, ESP, or Windows changes' ${provision}

    mkdir -p "$out"
    printf '%s\n' "generic provisioning safety checks passed" >"$out/README"
  ''
