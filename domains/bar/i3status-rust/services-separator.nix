{ pkgs }:

pkgs.writeShellApplication {
  name = "i3-services-separator";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.jq
    pkgs.systemd
  ];
  text = ''
    set -euo pipefail

    any=false

    if [[ -n "$(systemctl list-units --type=service --state=active --no-legend --plain --no-pager 'openvpn-*.service' 2>/dev/null || true)" ]]; then
      any=true
    fi
    if systemctl --user is-active --quiet sunshine.service; then
      any=true
    fi

    status_text() {
      local out
      out=$("$@" 2>/dev/null || true)
      [[ -n "$out" ]] || return 1
      jq -e '(.text // "") != ""' <<< "$out" >/dev/null 2>&1
    }

    if [[ "$any" != true ]]; then
      status_text angst-ftp-status status && any=true
      status_text angst-discord-voice status && any=true
      status_text i3-vm-grab status && any=true
      status_text i3-mouse-hide status && any=true
    fi

    if [[ "$any" == true ]]; then
      printf '{"text":"|","state":"Idle"}\n'
    else
      printf '{"text":"","state":"Idle"}\n'
    fi
  '';
}
