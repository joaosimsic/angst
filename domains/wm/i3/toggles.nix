{
  pkgs,
}:

pkgs.writeShellApplication {
  name = "i3-toggles";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.systemd
  ];
  text = ''
    set -euo pipefail

    vpn_unit="openvpn-cvx.service"
    sunshine_unit="sunshine.service"

    unit_info() {
      case "$1" in
        work-vpn) printf 'system %s\n' "$vpn_unit" ;;
        sunshine) printf 'user %s\n' "$sunshine_unit" ;;
        *)
          echo "i3-toggles: unknown toggle '$1'" >&2
          return 1
          ;;
      esac
    }

    systemctl_for() {
      local scope="$1"
      shift
      if [[ "$scope" == "user" ]]; then
        systemctl --user "$@"
      else
        systemctl "$@"
      fi
    }

    unit_exists() {
      local scope="$1" unit="$2"
      systemctl_for "$scope" cat "$unit" >/dev/null 2>&1
    }

    unit_state() {
      local scope="$1" unit="$2"
      if ! unit_exists "$scope" "$unit"; then
        printf 'UNAVAILABLE'
      elif systemctl_for "$scope" is-active --quiet "$unit"; then
        printf 'ON'
      else
        printf 'OFF'
      fi
    }

    status() {
      local scope unit
      read -r scope unit < <(unit_info work-vpn)
      printf '%-12s %s\n' "WORK VPN" "$(unit_state "$scope" "$unit")"
      read -r scope unit < <(unit_info sunshine)
      printf '%-12s %s\n' "SUNSHINE" "$(unit_state "$scope" "$unit")"
    }

    toggle() {
      local scope unit
      read -r scope unit < <(unit_info "$1")
      if ! unit_exists "$scope" "$unit"; then
        echo "i3-toggles: $unit is not available on this host" >&2
        exit 1
      fi
      if systemctl_for "$scope" is-active --quiet "$unit"; then
        systemctl_for "$scope" stop "$unit"
      else
        systemctl_for "$scope" start "$unit"
      fi
    }

    usage() {
      echo "usage: i3-toggles [status|toggle work-vpn|toggle sunshine]" >&2
      exit 2
    }

    case "''${1:-status}" in
      status) status ;;
      toggle)
        [[ $# -eq 2 ]] || usage
        toggle "$2"
        ;;
      *) usage ;;
    esac
  '';
}
