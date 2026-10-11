{
  mkScript,
  pkgs,
  lib,
  self,
}:
{ host }:
let
  homeDirsText = lib.concatStringsSep "\n" host.persist.homeDirs;
  homeFilesText = lib.concatStringsSep "\n" (host.persist.homeFiles or [ ]);
  flakeRef = "${self}#${host.hostname}";
in
mkScript {
  name = "install-nixos";
  runtimeInputs = with pkgs; [
    coreutils
    e2fsprogs
    util-linux
    gnused
    nixos-install-tools
    efibootmgr
  ];
  text = ''
    set -euo pipefail

    username=${lib.escapeShellArg host.username}
    flake_ref=${lib.escapeShellArg flakeRef}
    home_dirs=${lib.escapeShellArg homeDirsText}
    home_files=${lib.escapeShellArg homeFilesText}

    disk=/dev/nvme0n1
    migrate=1
    assume_yes=0
    dry_run=0
    mode=install

    die() {
      echo "error: $*" >&2
      exit 1
    }

    usage() {
      cat <<'EOF'
    Usage: install-nixos [options]

    Installs NixOS on the persist partition, keeping Windows and the shared
    ESP untouched.

    Options:
      --disk PATH     Disk to use (default: /dev/nvme0n1)
      --flake REF     Flake ref to install (default: this flake + host)
      --no-migrate    Do not move existing home state into /persist
      --cleanup       Remove Arch boot leftovers (run on the installed system)
      --yes           Do not ask for confirmation
      --dry-run       Print what would be done without changing anything
      -h, --help      Show this help
    EOF
    }

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --disk)
          disk=$2
          shift 2
          ;;
        --flake)
          flake_ref=$2
          shift 2
          ;;
        --no-migrate)
          migrate=0
          shift
          ;;
        --cleanup)
          mode=cleanup
          shift
          ;;
        --yes | -y)
          assume_yes=1
          shift
          ;;
        --dry-run)
          dry_run=1
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

    run() {
      if [ "$dry_run" -eq 1 ]; then
        printf '+ %s\n' "$*"
      else
        "$@"
      fi
    }

    require_root() {
      [ "$(id -u)" -eq 0 ] || die "must run as root (sudo nix run .#install-nixos)"
    }

    cleanup() {
      require_root
      echo "==> Removing Arch boot leftovers from the ESP"
      for path in \
        /boot/EFI/arch \
        /boot/grub \
        /boot/vmlinuz-linux \
        /boot/initramfs-linux.img \
        /boot/initramfs-linux-fallback.img; do
        if [ -e "$path" ]; then
          run rm -rf "$path"
        fi
      done

      echo "==> Removing stale Arch UEFI boot entries"
      if command -v efibootmgr >/dev/null; then
        while IFS= read -r line; do
          case "$line" in
            *EFI\\ARCH* | *EFI/ARCH*)
              entry=$(printf '%s' "$line" | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\).*/\1/p')
              [ -n "$entry" ] || continue
              run efibootmgr -b "$entry" -B
              ;;
          esac
        done < <(efibootmgr)
        echo "==> Remaining boot entries:"
        efibootmgr
      else
        echo "efibootmgr not available; skipping NVRAM cleanup"
      fi
      echo "==> Done. Windows and NixOS entries were left untouched."
    }

    if [ "$mode" = cleanup ]; then
      cleanup
      exit 0
    fi

    require_root
    [ -d /sys/firmware/efi ] || die "not booted in UEFI mode"
    [ -b "$disk" ] || die "disk not found: $disk"

    case "$disk" in
      *[0-9]) sep=p ;;
      *) sep= ;;
    esac
    esp="''${disk}''${sep}1"
    persist="''${disk}''${sep}3"
    home="''${disk}''${sep}4"

    for part in "$esp" "$persist" "$home"; do
      [ -b "$part" ] || die "partition not found: $part"
    done

    if findmnt -n /mnt >/dev/null 2>&1; then
      die "/mnt is already mounted"
    fi

    esp_type=$(blkid -s TYPE -o value "$esp")
    [ "$esp_type" = "vfat" ] || die "$esp is not a vfat ESP (found: $esp_type)"
    home_type=$(blkid -s TYPE -o value "$home")
    [ "$home_type" = "ext4" ] || die "$home is not ext4 (found: $home_type)"

    echo "==> Checking for the Windows bootloader on $esp"
    esp_check=$(mktemp -d)
    mount -o ro "$esp" "$esp_check"
    if [ ! -e "$esp_check/EFI/Microsoft/Boot/bootmgfw.efi" ]; then
      umount "$esp_check"
      rmdir "$esp_check"
      die "Windows bootloader not found on $esp - refusing to continue (wrong disk?)"
    fi
    umount "$esp_check"
    rmdir "$esp_check"

    cat <<SUMMARY
    ==> Plan for host '${host.hostname}'
      disk:     $disk
      ESP:      $esp (kept, shared with Windows)
      persist:  $persist (WILL BE FORMATTED ext4, label 'persist')
      home:     $home (kept, relabeled 'home')
      migrate:  $migrate
      flake:    $flake_ref
    SUMMARY

    if [ "$assume_yes" -ne 1 ]; then
      printf 'Type YES to continue: '
      read -r answer
      [ "$answer" = "YES" ] || die "aborted"
    fi

    echo "==> Formatting $persist"
    run mkfs.ext4 -L persist "$persist"

    if [ "$(blkid -s LABEL -o value "$home" 2>/dev/null || true)" != "home" ]; then
      echo "==> Labeling $home as 'home'"
      run e2label "$home" home
    fi

    echo "==> Mounting the target"
    run mount -t tmpfs -o size=2G tmpfs /mnt
    run mkdir -p /mnt/boot /mnt/home /mnt/persist /mnt/nix
    run mount "$esp" /mnt/boot
    run mount /dev/disk/by-label/home /mnt/home
    run mount /dev/disk/by-label/persist /mnt/persist
    run mkdir -p /mnt/home/nix
    run mount --bind /mnt/home/nix /mnt/nix

    if [ "$migrate" -eq 1 ]; then
      echo "==> Migrating state into /persist/home/$username"
      user_home="/mnt/home/$username"
      persist_home="/mnt/persist/home/$username"
      run mkdir -p "$persist_home"

      while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        src="$user_home/$rel"
        dst="$persist_home/$rel"
        if [ -e "$dst" ]; then
          echo "  skip (target exists): $rel"
        elif [ -e "$src" ]; then
          run mkdir -p "$(dirname "$dst")"
          run mv "$src" "$dst"
        else
          echo "  skip (not present): $rel"
        fi
      done <<<"$home_dirs"

      while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        src="$user_home/$rel"
        dst="$persist_home/$rel"
        if [ -e "$dst" ]; then
          echo "  skip (target exists): $rel"
        elif [ -e "$src" ]; then
          run mkdir -p "$(dirname "$dst")"
          run mv "$src" "$dst"
        else
          echo "  skip (not present): $rel"
        fi
      done <<<"$home_files"

      echo "==> Moving game data out of the ephemeral home"
      if [ -e "$user_home/.local/share/Steam" ] && [ ! -e /mnt/home/steam ]; then
        run mv "$user_home/.local/share/Steam" /mnt/home/steam
      fi
      if [ -e "$user_home/.local/share/PrismLauncher" ] && [ ! -e /mnt/home/prism ]; then
        run mv "$user_home/.local/share/PrismLauncher" /mnt/home/prism
      fi
    fi

    if [ "$dry_run" -eq 1 ]; then
      echo "==> Dry run complete; nothing was changed"
      exit 0
    fi

    echo "==> Installing NixOS ($flake_ref)"
    nixos-install --flake "$flake_ref" --impure

    cat <<'NEXT'
    ==> Install complete. Next steps:
      1. reboot; log in with the fallback password ('changeme') and run: passwd
         (or: angst bootstrap-master-password --host nixos)
      2. remove Arch boot leftovers:
           sudo nix run .#install-nixos -- --cleanup
      3. verify mounts: findmnt / /home /home/joao /persist
    NEXT
  '';
}
