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

  durableDirs = lib.unique (
    lib.concatMap (entries: builtins.filter (e: e.durable or false) entries) (
      builtins.attrValues (import ../../modules/nixos/persist-features.nix).features
    )
  );
  durablePairs = lib.concatMapStringsSep " " (d: "${d.dir}:${d.name}") durableDirs;

  hardwareRel =
    if host.domain != null then
      "hosts/${host.domain}/${host.hostname}/hardware.nix"
    else
      "hosts/${host.hostname}/hardware.nix";
in
mkScript {
  name = "install-nixos";
  runtimeInputs = with pkgs; [
    coreutils
    gawk
    gnused
    e2fsprogs
    dosfstools
    gptfdisk
    util-linux
    nixos-install-tools
    efibootmgr
    systemd
  ];
  text = ''
    set -euo pipefail

    username=${lib.escapeShellArg host.username}
    flake_ref=${lib.escapeShellArg flakeRef}
    home_dirs=${lib.escapeShellArg homeDirsText}
    home_files=${lib.escapeShellArg homeFilesText}
    durable_pairs=${lib.escapeShellArg durablePairs}
    hardware_rel=${lib.escapeShellArg hardwareRel}

    disk=""
    mode=install
    migrate=1
    assume_yes=0
    dry_run=0
    force_format=0
    identity_src=""
    gen_hardware=0
    repo_dir="."
    esp_size=1G
    swap_size=8G
    state_size=50G
    min_data_bytes=$((10 * 1024 * 1024 * 1024))

    die() {
      echo "error: $*" >&2
      exit 1
    }

    usage() {
      cat <<'EOF'
    Usage: install-nixos [options]

    Installs NixOS on the state partition, keeping Windows, the shared ESP and
    the data partition untouched. The data partition survives reinstalls and
    carries the durable user state (age keys, git config, browser, keyrings,
    cargo, projects).

    Disk modes:
      (default)        Partitions already exist (labels state/data, ESP with a
                       Windows bootloader); reinstall onto them.
      --dual-boot      Keep Windows and the shared ESP; create swap/state/data
                       partitions in the free space (shrink Windows first, the
                       installer never touches NTFS).
      --full-disk      Erase the whole disk and create ESP (partlabel boot),
                       swap, state and data from scratch.

    Options:
      --disk PATH     Disk to use (default: auto-detect when exactly one
                      non-removable disk without mounts)
      --flake REF     Flake ref to install (default: this flake + host)
      --fresh         Erase the state partition (implies --force-format and
                      --no-migrate). Durable data is copied to the data
                      partition first when not already there.
      --identity PATH Copy age keys from PATH into <data>/durable/age when no
                      identity is present yet (new machines).
      --hardware      Write nixos-generate-config output for the target; never
                      overwrites an existing hardware.nix (writes .generated)
      --repo PATH     Repo checkout for --hardware (default: .)
      --swap-size SZ  Swap partition size for provisioning (default: 8G)
      --state-size SZ State partition size for provisioning (default: 50G)
      --no-migrate    Do not move existing home state into the state partition
      --force-format  Format state even if a previous install is detected
      --cleanup       Remove Arch boot leftovers (run on the installed system)
      --yes           Do not ask for confirmation (full-disk still requires
                      typing the disk path)
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
        --dual-boot)
          [ "$mode" = "full-disk" ] && die "--dual-boot conflicts with --full-disk"
          mode=dual-boot
          migrate=0
          shift
          ;;
        --full-disk)
          [ "$mode" = "dual-boot" ] && die "--full-disk conflicts with --dual-boot"
          mode=full-disk
          migrate=0
          shift
          ;;
        --fresh)
          migrate=0
          force_format=1
          shift
          ;;
        --identity)
          identity_src=$2
          shift 2
          ;;
        --hardware)
          gen_hardware=1
          shift
          ;;
        --repo)
          repo_dir=$2
          shift 2
          ;;
        --swap-size)
          swap_size=$2
          shift 2
          ;;
        --state-size)
          state_size=$2
          shift 2
          ;;
        --no-migrate)
          migrate=0
          shift
          ;;
        --force-format)
          force_format=1
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

    if [ "$dry_run" -eq 0 ]; then
      require_root
    fi
    [ -d /sys/firmware/efi ] || die "not booted in UEFI mode"

    part_by_label() {
      local want=$1 dev
      for dev in $(lsblk -nlo PATH "$disk" 2>/dev/null || true); do
        [ "$dev" = "$disk" ] && continue
        if [ "$(blkid -s LABEL -o value "$dev" 2>/dev/null || true)" = "$want" ]; then
          printf '%s' "$dev"
          return 0
        fi
      done
      return 1
    }

    part_by_partlabel() {
      local want=$1 dev
      for dev in $(lsblk -nlo PATH "$disk" 2>/dev/null || true); do
        [ "$dev" = "$disk" ] && continue
        if [ "$(blkid -s PARTLABEL -o value "$dev" 2>/dev/null || true)" = "$want" ]; then
          printf '%s' "$dev"
          return 0
        fi
      done
      return 1
    }

    esp_with_windows() {
      local dev probe found mp
      for dev in $(lsblk -nlo PATH "$disk" 2>/dev/null || true); do
        [ "$dev" = "$disk" ] && continue
        case "$(blkid -s PARTTYPE -o value "$dev" 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)" in
          c12a7328-f81f-11d2-ba4b-00a0c93ec93b) ;;
          *) continue ;;
        esac
        found=0
        if mp=$(findmnt -S "$dev" -n -o TARGET | head -n 1) && [ -n "$mp" ]; then
          [ -e "$mp/EFI/Microsoft/Boot/bootmgfw.efi" ] && found=1
        else
          probe=$(mktemp -d)
          if mount -o ro "$dev" "$probe" 2>/dev/null; then
            [ -e "$probe/EFI/Microsoft/Boot/bootmgfw.efi" ] && found=1
            umount "$probe"
          fi
          rmdir "$probe"
        fi
        if [ "$found" -eq 1 ]; then
          printf '%s' "$dev"
          return 0
        fi
      done
      return 1
    }

    disk_has_windows() {
      local dev
      for dev in $(lsblk -nlo PATH "$disk" 2>/dev/null || true); do
        [ "$dev" = "$disk" ] && continue
        case "$(blkid -s TYPE -o value "$dev" 2>/dev/null || true)" in
          ntfs*) return 0 ;;
        esac
      done
      return 1
    }

    select_disk() {
      if [ -n "$disk" ]; then
        [ -b "$disk" ] || die "disk not found: $disk"
        return 0
      fi
      local candidates=() name rm type dev mounts
      while read -r name rm type; do
        [ "$type" = "disk" ] || continue
        [ "$rm" = "0" ] || continue
        dev="/dev/$name"
        mounts=$(lsblk -nlo MOUNTPOINTS "$dev" 2>/dev/null | grep -v '^$' | head -n 1 || true)
        [ -n "$mounts" ] && continue
        candidates+=("$dev")
      done < <(lsblk -dn -o NAME,RM,TYPE)
      case "''${#candidates[@]}" in
        1) disk="''${candidates[0]}" ;;
        0) die "no candidate disk found; pass --disk PATH" ;;
        *) die "multiple disks found (''${candidates[*]}); pass --disk PATH" ;;
      esac
      echo "==> Using disk $disk"
    }

    disk_suffix() {
      case "$1" in
        *[0-9]) printf 'p' ;;
        *) printf "" ;;
      esac
    }

    provision_full_disk() {
      echo "==> Erasing $disk and creating a fresh GPT layout"
      run wipefs -a "$disk"
      run sgdisk --zap-all "$disk"
      run sgdisk -n "1:0:+$esp_size" -t 1:ef00 -c 1:boot "$disk"
      run sgdisk -n "2:0:+$swap_size" -t 2:8200 -c 2:swap "$disk"
      run sgdisk -n "3:0:+$state_size" -t 3:8300 -c 3:state "$disk"
      run sgdisk -n "4:0:0" -t 4:8300 -c 4:data "$disk"
      run partx -u "$disk"
      run udevadm settle
      if [ "$dry_run" -eq 1 ]; then
        return 0
      fi
      local sep
      sep=$(disk_suffix "$disk")
      run mkfs.fat -F 32 -n boot "''${disk}''${sep}1"
      run mkswap -L swap "''${disk}''${sep}2"
      run mkfs.ext4 -F -L state "''${disk}''${sep}3"
      run mkfs.ext4 -F -L data "''${disk}''${sep}4"
    }

    provision_dual_boot() {
      local esp partn total last_end free_bytes need_bytes
      esp=$(esp_with_windows) || die "no ESP with a Windows bootloader found on $disk (wrong disk? shrink Windows first?)"
      partn=$(basename "$esp" | sed 's/^[^0-9]*//')
      if [ "$(blkid -s PARTLABEL -o value "$esp" 2>/dev/null || true)" != "boot" ]; then
        echo "==> Naming the shared ESP partition 'boot' (metadata only)"
        run sgdisk -c "$partn:boot" "$disk"
      fi

      total=$(sgdisk -p "$disk" | awk '/^Disk / { for (i = 1; i <= NF; i++) if ($i == "sectors,") { print $(i - 1); exit } }')
      last_end=$(sgdisk -p "$disk" | awk '$1 ~ /^[0-9]+$/ { end = $3 } END { print end + 0 }')
      [ -n "$total" ] && [ "$total" -gt 0 ] || die "could not read the partition table of $disk"
      free_bytes=$(( (total - last_end - 33) * 512 ))
      need_bytes=$(( $(numfmt --from=iec "$swap_size") + $(numfmt --from=iec "$state_size") + min_data_bytes ))
      if [ "$free_bytes" -lt "$need_bytes" ]; then
        die "not enough free space after the last partition: $((free_bytes / 1024 / 1024)) MiB free, $((need_bytes / 1024 / 1024)) MiB needed (shrink Windows first, or use --full-disk on another disk)"
      fi

      echo "==> Creating swap, state and data in the free space"
      local n
      n=$(sgdisk -f "$disk") || die "no free partition slot on $disk"
      run sgdisk -n "$n:0:+$swap_size" -t "$n:8200" -c "$n:swap" "$disk"
      n=$(sgdisk -f "$disk") || die "no free partition slot on $disk"
      run sgdisk -n "$n:0:+$state_size" -t "$n:8300" -c "$n:state" "$disk"
      n=$(sgdisk -f "$disk") || die "no free partition slot on $disk"
      run sgdisk -n "$n:0:0" -t "$n:8300" -c "$n:data" "$disk"
      run partx -u "$disk"
      run udevadm settle
      if [ "$dry_run" -eq 1 ]; then
        return 0
      fi
      local swap_dev state_dev data_dev
      swap_dev=$(part_by_partlabel swap) || die "swap partition not found after provisioning"
      state_dev=$(part_by_partlabel state) || die "state partition not found after provisioning"
      data_dev=$(part_by_partlabel data) || die "data partition not found after provisioning"
      run mkswap -L swap "$swap_dev"
      run mkfs.ext4 -F -L state "$state_dev"
      run mkfs.ext4 -F -L data "$data_dev"
    }

    select_disk

    esp=""
    state_part=""
    data_part=""

    case "$mode" in
      full-disk)
        if [ "$dry_run" -eq 0 ]; then
          printf 'Type the disk path (%s) to confirm erasing it: ' "$disk"
          read -r answer
          [ "$answer" = "$disk" ] || die "aborted"
        fi
        provision_full_disk
        ;;
      dual-boot)
        provision_dual_boot
        ;;
      install)
        ;;
    esac

    if [ "$dry_run" -eq 0 ]; then
      esp=$(part_by_partlabel boot 2>/dev/null || true)
      [ -n "$esp" ] || esp=$(esp_with_windows 2>/dev/null || true)
      [ -n "$esp" ] || die "no ESP found on $disk (expected a Windows bootloader or partlabel 'boot')"
      state_part=$(part_by_label state 2>/dev/null || part_by_label persist 2>/dev/null || true)
      data_part=$(part_by_label data 2>/dev/null || part_by_label home 2>/dev/null || true)
      [ -n "$state_part" ] || die "no state partition on $disk (label 'state'); use --dual-boot or --full-disk to create one"
      [ -n "$data_part" ] || die "no data partition on $disk (label 'data'); use --dual-boot or --full-disk to create one"

      if [ "$mode" = "install" ] && disk_has_windows; then
        probe=$(mktemp -d)
        if mount -o ro "$esp" "$probe" 2>/dev/null; then
          found=0
          [ -e "$probe/EFI/Microsoft/Boot/bootmgfw.efi" ] && found=1
          umount "$probe"
          rmdir "$probe"
          [ "$found" -eq 1 ] || die "Windows bootloader not found on $esp - refusing to continue (wrong disk?)"
        else
          rmdir "$probe"
          die "could not mount $esp read-only; aborting"
        fi
      fi
      if [ "$(blkid -s PARTLABEL -o value "$esp" 2>/dev/null || true)" != "boot" ]; then
        partn=$(basename "$esp" | sed 's/^[^0-9]*//')
        run sgdisk -c "$partn:boot" "$disk"
      fi

      esp_type=$(blkid -s TYPE -o value "$esp")
      [ "$esp_type" = "vfat" ] || die "$esp is not a vfat ESP (found: $esp_type)"
      data_type=$(blkid -s TYPE -o value "$data_part")
      [ "$data_type" = "ext4" ] || die "$data_part is not ext4 (found: $data_type)"
    fi

    if [ "$dry_run" -eq 1 ]; then
      case "$mode" in
        full-disk)
          esp="<new ESP, partlabel boot>"
          state_part="<new state partition>"
          data_part="<new data partition>"
          ;;
        dual-boot)
          esp="<shared ESP>"
          state_part="<new state partition>"
          data_part="<new data partition>"
          ;;
      esac
    fi

    state_reuse=0
    if [ "$force_format" -eq 0 ] && [ "$dry_run" -eq 0 ]; then
      state_label=$(blkid -s LABEL -o value "$state_part" 2>/dev/null || true)
      case "$state_label" in
        state | persist)
          probe=$(findmnt -S "$state_part" -n -o TARGET | head -n 1)
          probe_mount=""
          if [ -z "$probe" ]; then
            probe=$(mktemp -d)
            if mount -o ro "$state_part" "$probe" 2>/dev/null; then
              probe_mount=$probe
            else
              probe=""
            fi
          fi
          if [ -n "$probe" ] && [ -d "$probe/home/$username" ]; then
            state_reuse=1
          fi
          if [ -n "$probe_mount" ]; then
            umount "$probe_mount"
            rmdir "$probe_mount"
          fi
          ;;
      esac
    fi

    if [ "$state_reuse" -eq 1 ]; then
      state_note="$state_part (reused, existing data preserved)"
    else
      state_note="$state_part (WILL BE FORMATTED ext4, label 'state')"
    fi

    cat <<SUMMARY
    ==> Plan for host '${host.hostname}'
      mode:     $mode
      disk:     $disk
      ESP:      $esp (kept, shared with Windows)
      state:    $state_note
      data:     $data_part (kept, relabeled 'data')
      durable:  $data_part:/durable keeps age keys, git, browser, keyrings, cargo, projects
      migrate:  $migrate
      flake:    $flake_ref
    SUMMARY

    if [ "$assume_yes" -ne 1 ]; then
      printf 'Type YES to continue: '
      read -r answer
      [ "$answer" = "YES" ] || die "aborted"
    fi

    echo "==> Cleaning up mounts from previous runs"
    if findmnt -n /mnt >/dev/null 2>&1; then
      run umount -R /mnt
    fi
    for stale_part in "$esp" "$state_part" "$data_part"; do
      [ -n "$stale_part" ] || continue
      while IFS= read -r stale; do
        [ -n "$stale" ] || continue
        echo "  unmounting $stale"
        run umount "$stale"
      done < <(findmnt -S "$stale_part" -n -o TARGET)
    done

    echo "==> Mounting the target"
    run mount -t tmpfs -o size=2G,mode=755 tmpfs /mnt
    run mkdir -p /mnt/boot /mnt/home /mnt/state /mnt/nix
    run mount "$esp" /mnt/boot
    if [ "$dry_run" -eq 0 ] && findmnt -no OPTIONS /mnt/boot | grep -qE '(^|,)ro(,|$)'; then
      die "$esp mounted read-only (a stale mount is still holding it); aborting"
    fi
    run mount "$data_part" /mnt/home

    if [ "$dry_run" -eq 0 ] && [ "$(blkid -s LABEL -o value "$data_part" 2>/dev/null || true)" != "data" ]; then
      echo "==> Labeling $data_part as 'data'"
      run e2label "$data_part" data
      run udevadm trigger --action=change --settle "$data_part"
    fi

    if [ "$state_reuse" -eq 1 ]; then
      echo "==> Reusing $state_part (previous interrupted install detected); data preserved"
      if [ "$dry_run" -eq 0 ] && [ "$(blkid -s LABEL -o value "$state_part" 2>/dev/null || true)" != "state" ]; then
        run e2label "$state_part" state
      fi
    else
      echo "==> Formatting $state_part"
      run mkfs.ext4 -F -L state "$state_part"
      run udevadm trigger --action=change --settle "$state_part"
    fi
    run mount "$state_part" /mnt/state

    echo "==> Ensuring durable state on $data_part"
    run mkdir -p /mnt/home/durable
    if [ "$dry_run" -eq 0 ] && [ ! -e /mnt/home/durable/age/keys.txt ] && [ -d "/mnt/state/home/$username" ]; then
      echo "  copying durable data from the state partition"
      for pair in $durable_pairs; do
        rel="''${pair%%:*}"
        name="''${pair##*:}"
        src="/mnt/state/home/$username/$rel"
        dst="/mnt/home/durable/$name"
        if [ -e "$dst" ]; then
          echo "    skip (target exists): $name"
        elif [ -e "$src" ]; then
          run mkdir -p "$(dirname "$dst")"
          run cp -a "$src" "$dst"
          echo "    copied: $name"
        else
          echo "    skip (not present): $name"
        fi
      done
    fi
    for pair in $durable_pairs; do
      name="''${pair##*:}"
      run mkdir -p "/mnt/home/durable/$name"
    done
    run chown -R 1000:100 /mnt/home/durable

    if [ -n "$identity_src" ]; then
      [ -d "$identity_src" ] || die "--identity: not a directory: $identity_src"
      if [ "$dry_run" -eq 0 ] && [ -e /mnt/home/durable/age/keys.txt ]; then
        echo "==> Identity already present; ignoring --identity"
      else
        echo "==> Seeding age identity from $identity_src"
        run cp -a "$identity_src/." /mnt/home/durable/age/
        run chown -R 1000:100 /mnt/home/durable/age
      fi
    fi

    if [ "$dry_run" -eq 0 ] && [ ! -e /mnt/home/durable/age/keys.txt ]; then
      echo "==> WARNING: no age identity at /mnt/home/durable/age/keys.txt"
      echo "    the host will boot with the fallback password; restore the keys and"
      echo "    rebuild to recover secrets"
    fi

    run mkdir -p /mnt/home/nix
    run mount --bind /mnt/home/nix /mnt/nix

    if [ "$migrate" -eq 1 ]; then
      echo "==> Migrating state into /mnt/state/home/$username"
      user_home="/mnt/home/$username"
      state_home="/mnt/state/home/$username"
      run mkdir -p "$state_home"

      while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        src="$user_home/$rel"
        dst="$state_home/$rel"
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
        dst="$state_home/$rel"
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

    if [ "$gen_hardware" -eq 1 ] && [ "$dry_run" -eq 0 ]; then
      target="$repo_dir/$hardware_rel"
      gen=$(mktemp)
      echo "==> Generating hardware config for the target"
      nixos-generate-config --root /mnt --show-hardware-config >"$gen"
      if [ -e "$target" ]; then
        cp "$gen" "$target.generated"
        echo "    kept existing $target; generated output in $target.generated"
      else
        mkdir -p "$(dirname "$target")"
        cp "$gen" "$target"
        echo "    wrote $target"
      fi
      rm -f "$gen"
    fi

    if [ "$dry_run" -eq 1 ]; then
      echo "==> Dry run complete; nothing was changed"
      exit 0
    fi

    echo "==> Installing NixOS ($flake_ref)"
    nixos-install --flake "$flake_ref" --impure

    cat <<'NEXT'
    ==> Install complete. Next steps:
      1. reboot; the age identity lives on the data partition, so the boot
         service applies the selected password automatically
      2. only if no identity was found: log in with the fallback password
         ('changeme'), restore the age keys to /home/durable/age, then run:
           angst bootstrap-password --name main --scope personal
      3. verify mounts: findmnt / /home /home/joao /state /home/durable/age
    NEXT
  '';
}
