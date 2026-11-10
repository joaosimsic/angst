{ pkgs }:

pkgs.writeShellApplication {
  name = "i3-vpn-status";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.systemd
  ];
  text = ''
    set -euo pipefail

    if systemctl is-active --quiet openvpn-cvx.service; then
      printf '{"icon":"net_vpn","state":"Good","text":"vpn"}\n'
    else
      printf '{"icon":"","state":"Idle","text":""}\n'
    fi
  '';
}
