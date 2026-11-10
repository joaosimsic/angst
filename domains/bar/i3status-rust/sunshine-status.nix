{ pkgs }:

pkgs.writeShellApplication {
  name = "i3-sunshine-status";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.systemd
  ];
  text = ''
    set -euo pipefail

    log="''${SUNSHINE_LOG:-$HOME/.config/sunshine/sunshine.log}"

    if ! systemctl --user is-active --quiet sunshine.service; then
      printf '{"icon":"sunshine_off","state":"Idle","text":""}\n'
      exit 0
    fi

    event=""
    if [ -r "$log" ]; then
      event=$(tac "$log" 2>/dev/null | grep -m1 -E 'New streaming session started \[active sessions: [0-9]+\]|CLIENT DISCONNECTED' || true)
    fi

    case "$event" in
      *"CLIENT DISCONNECTED"*)
        printf '{"icon":"sunshine","state":"Idle","text":""}\n'
        ;;
      *"New streaming session started"*)
        printf '{"icon":"sunshine_active","state":"Good","text":""}\n'
        ;;
      *)
        printf '{"icon":"sunshine","state":"Idle","text":""}\n'
        ;;
    esac
  '';
}
