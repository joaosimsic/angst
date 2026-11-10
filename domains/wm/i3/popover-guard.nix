{
  pkgs,
  popoverClose,
}:

pkgs.writeShellApplication {
  name = "i3-popover-guard";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.xbindkeys
  ];
  text = ''
    set -euo pipefail

    runtime="''${XDG_RUNTIME_DIR:-/tmp}"
    guard_pidfile="$runtime/i3-popover-keys.pid"
    guard_config="$runtime/i3-popover-keys.conf"
    popovers=(i3-hardware-menu i3-network-menu i3-toggles-menu i3-cheatsheet)

    guard_running() {
      local pid
      [[ -r "$guard_pidfile" ]] || return 1
      pid="$(cat "$guard_pidfile" 2>/dev/null || true)"
      [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
    }

    start() {
      if guard_running; then
        return 0
      fi
      rm -f "$guard_pidfile"
      printf '"%s"\n    Escape\n' "${popoverClose}/bin/i3-popover-close" > "$guard_config"
      xbindkeys --nodaemon -f "$guard_config" >/dev/null 2>"$runtime/i3-popover-keys.log" &
      printf '%s\n' "$!" > "$guard_pidfile"
    }

    sync() {
      local name pidfile pid
      for name in "''${popovers[@]}"; do
        pidfile="$runtime/$name.pid"
        [[ -r "$pidfile" ]] || continue
        pid="$(cat "$pidfile" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
          return 0
        fi
      done
      if guard_running; then
        kill "$(cat "$guard_pidfile")" 2>/dev/null || true
      fi
      rm -f "$guard_pidfile"
    }

    case "''${1:-}" in
      start) start ;;
      sync) sync ;;
      *)
        echo "usage: i3-popover-guard [start|sync]" >&2
        exit 2
        ;;
    esac
  '';
}
