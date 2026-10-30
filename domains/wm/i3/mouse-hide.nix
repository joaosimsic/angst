{
  pkgs,
  i3Tools,
}:

pkgs.writeShellApplication {
  name = "i3-mouse-hide";
  runtimeInputs = [
    i3Tools
    pkgs.coreutils
    pkgs.xinput
  ];
  text = ''
    set -euo pipefail

    HOLD="${i3Tools}/bin/i3-mouse-hold"
    RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/tmp}"
    PID_FILE="$RUNTIME_DIR/i3-mouse-hide-''${UID}.pid"
    DEVICES_FILE="$RUNTIME_DIR/i3-mouse-hide-devices-''${UID}"

    cursor_hidden() {
      [ -s "$PID_FILE" ] || return 1
      pid=$(cat "$PID_FILE")
      [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
    }

    hide_cursor() {
      if cursor_hidden; then
        return 0
      fi
      rm -f "$PID_FILE"
      nohup "$HOLD" >/dev/null 2>&1 &
      printf '%s\n' "$!" > "$PID_FILE"
    }

    show_cursor() {
      if ! cursor_hidden; then
        rm -f "$PID_FILE"
        return 0
      fi
      pid=$(cat "$PID_FILE")
      kill "$pid" 2>/dev/null || true
      for _ in $(seq 1 50); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.02
      done
      rm -f "$PID_FILE"
    }

    pointer_ids() {
      xinput list --short 2>/dev/null |
        sed -n 's/.*id=\([0-9][0-9]*\).*\[slave[[:space:]]\+pointer.*/\1/p'
    }

    device_enabled() {
      xinput list-props "$1" 2>/dev/null |
        grep -Eq 'Device Enabled.*:[[:space:]]*1([[:space:]]|$)'
    }

    device_disabled() {
      xinput list-props "$1" 2>/dev/null |
        grep -Eq 'Device Enabled.*:[[:space:]]*0([[:space:]]|$)'
    }

    is_disabled() {
      [ -s "$DEVICES_FILE" ] || return 1
      while IFS= read -r id; do
        [ -n "$id" ] || continue
        if device_disabled "$id"; then
          return 0
        fi
      done < "$DEVICES_FILE"
      return 1
    }

    disable() {
      if is_disabled; then
        return 0
      fi
      rm -f "$DEVICES_FILE"
      for id in $(pointer_ids); do
        if device_enabled "$id"; then
          if xinput disable "$id" 2>/dev/null; then
            printf '%s\n' "$id" >> "$DEVICES_FILE"
          fi
        fi
      done
      if [ ! -s "$DEVICES_FILE" ]; then
        echo "i3-mouse-hide: no pointer devices disabled" >&2
        rm -f "$DEVICES_FILE"
        return 1
      fi
      hide_cursor
    }

    enable() {
      show_cursor
      if [ -s "$DEVICES_FILE" ]; then
        while IFS= read -r id; do
          [ -n "$id" ] || continue
          xinput enable "$id" 2>/dev/null || true
        done < "$DEVICES_FILE"
      fi
      rm -f "$DEVICES_FILE"
    }

    toggle() {
      if is_disabled; then
        enable
      else
        disable
      fi
    }

    status() {
      if is_disabled; then
        printf '{"icon":"mouse","state":"Critical","text":""}\n'
      else
        printf '{"icon":"mouse","state":"Good","text":""}\n'
      fi
    }

    case "''${1:-status}" in
      disable|hide)
        disable
        ;;
      enable|show)
        enable
        ;;
      toggle)
        toggle
        ;;
      status)
        status
        ;;
      -h|--help|help)
        echo "Usage: i3-mouse-hide [disable|enable|toggle|status]"
        ;;
      *)
        echo "Unknown action: $1" >&2
        exit 1
        ;;
    esac
  '';
}
