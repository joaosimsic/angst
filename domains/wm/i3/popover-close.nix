{
  pkgs,
}:

pkgs.writeShellApplication {
  name = "i3-popover-close";
  runtimeInputs = [
    pkgs.coreutils
  ];
  text = ''
    set -euo pipefail

    runtime="''${XDG_RUNTIME_DIR:-/tmp}"
    guard_pidfile="$runtime/i3-popover-keys.pid"

    close_popover() {
      local name="$1"
      local pidfile="$runtime/$name.pid"
      local pid=""

      [[ -r "$pidfile" ]] || return 0
      pid="$(cat "$pidfile" 2>/dev/null || true)"
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
      fi
      rm -f "$pidfile"
    }

    for name in i3-hardware-menu i3-network-menu i3-toggles-menu i3-cheatsheet; do
      close_popover "$name"
    done

    if [[ -r "$guard_pidfile" ]]; then
      guard="$(cat "$guard_pidfile" 2>/dev/null || true)"
      if [[ -n "$guard" ]] && kill -0 "$guard" 2>/dev/null; then
        kill "$guard" 2>/dev/null || true
      fi
      rm -f "$guard_pidfile"
    fi
  '';
}
