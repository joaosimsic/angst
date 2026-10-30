{
  pkgs,
  hardwareMetrics,
}:

pkgs.writeShellApplication {
  name = "i3-hardware-menu";
  runtimeInputs = [
    pkgs.conky
    pkgs.coreutils
    hardwareMetrics
  ];
  text = ''
    set -euo pipefail

    runtime="''${XDG_RUNTIME_DIR:-/tmp}"
    pidfile="$runtime/i3-hardware-menu.pid"

    if [ -r "$pidfile" ]; then
      pid=$(cat "$pidfile" 2>/dev/null || true)
      if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        rm -f "$pidfile"
        exit 0
      fi
    fi

    conky -c "$HOME/.config/i3/hardware-menu.conky" >/dev/null 2>"$runtime/i3-hardware-menu.log" &
    pid=$!
    printf '%s\n' "$pid" > "$pidfile"
    wait "$pid" || true
    rm -f "$pidfile"
  '';
}
