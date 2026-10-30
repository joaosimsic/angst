{ pkgs }:

pkgs.writeShellApplication {
  name = "i3-audio-mute";
  runtimeInputs = [
    pkgs.gnugrep
    pkgs.playerctl
    pkgs.wireplumber
  ];
  text = ''
    set -euo pipefail

    statuses=$(playerctl -a status 2>/dev/null || true)

    if printf '%s\n' "$statuses" | grep -qx Playing; then
      playerctl -a pause
    else
      wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    fi
  '';
}
