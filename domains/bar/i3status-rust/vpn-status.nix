{ pkgs }:

pkgs.writeShellApplication {
  name = "i3-vpn-status";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.systemd
  ];
  text = ''
    set -euo pipefail

    units="$(systemctl list-units --type=service --state=active --no-legend --plain --no-pager 'openvpn-*.service' 2>/dev/null || true)"
    names=()
    while read -r unit _; do
      [[ -n "$unit" ]] || continue
      name="''${unit#openvpn-}"
      names+=("''${name%.service}")
    done <<< "$units"

    if (( ''${#names[@]} > 0 )); then
      printf '{"icon":"net_vpn","state":"Good","text":"%s"}\n' "''${names[*]}"
    else
      printf '{"icon":"","state":"Idle","text":""}\n'
    fi
  '';
}
