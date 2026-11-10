{
  pkgs,
  popoverGuard,
}:

pkgs.writeShellApplication {
  name = "i3-toggles-menu";
  runtimeInputs = [
    pkgs.conky
    pkgs.coreutils
    popoverGuard
  ];
  text = ''
    set -euo pipefail

    runtime="''${XDG_RUNTIME_DIR:-/tmp}"
    pidfile="$runtime/i3-toggles-menu.pid"

    if [ -r "$pidfile" ]; then
      pid=$(cat "$pidfile" 2>/dev/null || true)
      if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        rm -f "$pidfile"
        exit 0
      fi
    fi

    conky -c "$HOME/.config/i3/toggles-menu.conky" >/dev/null 2>"$runtime/i3-toggles-menu.log" &
    pid=$!
    printf '%s\n' "$pid" > "$pidfile"
    i3-popover-guard start || true
    wait "$pid" || true
    rm -f "$pidfile"
    i3-popover-guard sync || true
  '';
}
