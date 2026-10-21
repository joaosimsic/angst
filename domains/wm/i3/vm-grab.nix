{ pkgs }:

pkgs.writeShellApplication {
  name = "i3-vm-grab";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.xdotool
  ];
  text = ''
    set -euo pipefail

    GUEST_DIR="/tmp/shared"
    STATE_DIR="''${VM_GRAB_SHARED_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}/vm/keys/vm}"
    REQUEST_FILE="$STATE_DIR/grab-request"
    STATE_FILE="$STATE_DIR/grab-state"

    qemu_window() {
      local id name
      for id in $(xdotool search --class qemu 2>/dev/null || true); do
        name=$(xdotool getwindowname "$id" 2>/dev/null || true)
        case "$name" in
          QEMU\ \(*\))
            case "$name" in
              *": "*) continue ;;
            esac
            printf '%s\n' "$id"
            return 0
            ;;
        esac
      done
      for id in $(xdotool search --name '^QEMU \(' 2>/dev/null || true); do
        name=$(xdotool getwindowname "$id" 2>/dev/null || true)
        case "$name" in
          *": "*) continue ;;
        esac
        printf '%s\n' "$id"
        return 0
      done
      return 1
    }

    grabbed() {
      local id="$1"
      local name
      name=$(xdotool getwindowname "$id" 2>/dev/null || true)
      case "$name" in
        *"release grab"*) return 0 ;;
        *) return 1 ;;
      esac
    }

    write_state() {
      mkdir -p "$STATE_DIR"
      printf '%s\n' "$1" > "$STATE_FILE.tmp"
      mv -f "$STATE_FILE.tmp" "$STATE_FILE"
    }

    print_state() {
      case "$1" in
        grabbed)
          printf '{"icon":"gpu","state":"Critical","text":"Super+G"}\n'
          ;;
        *)
          printf '{"icon":"gpu","state":"Good","text":"Super+G"}\n'
          ;;
      esac
    }

    toggle() {
      local id active
      id=$(qemu_window) || return 0
      active=$(xdotool getactivewindow 2>/dev/null || true)
      if [ "$active" != "$id" ]; then
        xdotool windowactivate --sync "$id" 2>/dev/null ||
          xdotool windowfocus --sync "$id" 2>/dev/null ||
          true
      fi
      xdotool key --clearmodifiers super+g
      sleep 0.2
      if grabbed "$id"; then
        write_state grabbed
      else
        write_state released
      fi
    }

    status_host() {
      local id
      if ! id=$(qemu_window); then
        rm -f "$STATE_FILE"
        printf '{"icon":"","state":"Idle","text":""}\n'
        return 0
      fi
      if grabbed "$id"; then
        write_state grabbed
        print_state grabbed
      else
        write_state released
        print_state released
      fi
    }

    status_guest() {
      local state=released
      if [ -f "$GUEST_DIR/grab-state" ]; then
        state=$(cat "$GUEST_DIR/grab-state" 2>/dev/null || printf 'released')
      fi
      print_state "$state"
    }

    request() {
      mkdir -p "$GUEST_DIR"
      printf 'toggle\n' > "$GUEST_DIR/grab-request.tmp"
      mv -f "$GUEST_DIR/grab-request.tmp" "$GUEST_DIR/grab-request"
      sleep 0.4
    }

    handle_request() {
      local action
      [ -f "$REQUEST_FILE" ] || return 0
      action=$(cat "$REQUEST_FILE" 2>/dev/null || true)
      rm -f "$REQUEST_FILE"
      if [ "$action" = "toggle" ]; then
        toggle
      fi
    }

    case "''${1:-status}" in
      status)
        if [ "''${2:-}" = "--guest" ]; then
          status_guest
        else
          status_host
        fi
        ;;
      toggle)
        toggle
        ;;
      request)
        request
        ;;
      handle-request)
        handle_request
        ;;
      -h|--help|help)
        echo "Usage: i3-vm-grab [status [--guest]|toggle|request|handle-request]"
        ;;
      *)
        echo "Unknown action: $1" >&2
        exit 1
        ;;
    esac
  '';
}
