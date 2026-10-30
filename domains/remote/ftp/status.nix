{
  lib,
  pkgs,
  mounts,
}:

let
  shellArray = values: lib.concatMapStringsSep "\n      " (value: lib.escapeShellArg value) values;
in
pkgs.writeShellApplication {
  name = "angst-ftp-status";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.systemd
    pkgs.util-linux
  ];
  text = ''
    set -euo pipefail

    runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    state_file="$runtime_dir/angst/ftp-enabled"

    mount_paths=(
      ${shellArray (map (m: m.mountPoint) mounts)}
    )
    services=(
      ${shellArray (map (m: m.service) mounts)}
    )

    active_count() {
      local count=0 path
      for path in "''${mount_paths[@]}"; do
        if mountpoint -q "$HOME/$path" 2>/dev/null; then
          count=$((count + 1))
        fi
      done
      printf '%s\n' "$count"
    }

    status() {
      local total="''${#mount_paths[@]}"
      local active
      active=$(active_count)
      if (( active == 0 )); then
        printf '{"icon":"net_down","state":"Idle","text":"ftp"}\n'
      elif (( active == total )); then
        printf '{"icon":"net_up","state":"Good","text":"ftp"}\n'
      else
        printf '{"icon":"net_up","state":"Warning","text":"ftp %d/%d"}\n' "$active" "$total"
      fi
    }

    wait_for_state() {
      local want=$1 _
      for _ in $(seq 1 50); do
        if [ "$(active_count)" = "$want" ]; then
          return 0
        fi
        sleep 0.1
      done
    }

    toggle() {
      local active
      active=$(active_count)
      if (( active > 0 )); then
        for service in "''${services[@]}"; do
          systemctl --user stop "$service" || true
        done
        rm -f "$state_file"
        wait_for_state 0
      else
        mkdir -p "$(dirname "$state_file")"
        : > "$state_file"
        for service in "''${services[@]}"; do
          systemctl --user start "$service" || true
        done
        wait_for_state "''${#mount_paths[@]}"
      fi
    }

    case "''${1:-status}" in
      status)
        status
        ;;
      toggle)
        toggle
        ;;
      -h|--help|help)
        echo "Usage: angst-ftp-status [status|toggle]"
        ;;
      *)
        echo "Unknown action: $1" >&2
        exit 2
        ;;
    esac
  '';
}
