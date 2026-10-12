{
  lib,
  pkgs,
  themesLib,
  renderDomainOutputFor,
}:

let
  themeNames = lib.attrNames themesLib.themes;

  renderForTheme = themeName: {
    inherit themeName;
    i3Config = renderDomainOutputFor themeName "domains/wm/i3/config/config";
    i3statusRustConfig = renderDomainOutputFor themeName "domains/bar/i3status-rust/config/config.toml";
  };

  rendered = map renderForTheme themeNames;

  checkTheme =
    {
      themeName,
      i3Config,
      i3statusRustConfig,
    }:
    pkgs.runCommand "lint-desktop-${themeName}"
      {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.i3
          pkgs.i3status-rust
        ];
      }
      ''
        mkdir -p home/.config/i3
        cp ${pkgs.writeText "monitors-${themeName}.conf" ''
          exec --no-startup-id xrandr --output DP-1 --mode 1920x1080 --rate 144 --pos 0x0
          exec --no-startup-id xrandr --output HDMI-A-2 --mode 1920x1080 --rate 60 --pos 1920x0
        ''} home/.config/i3/monitors.conf
        cp ${pkgs.writeText "i3-${themeName}.conf" i3Config} i3.conf
        cp ${pkgs.writeText "i3status-rust-${themeName}.toml" i3statusRustConfig} config.toml

        echo "Validating i3 config for theme ${themeName}..."
        HOME="$PWD/home" i3 -C -c i3.conf

        echo "Validating i3status-rust config for theme ${themeName}..."
        timeout 2 i3status-rs "$PWD/config.toml" >/dev/null 2>i3status-rust.err || test $? -eq 124
        if grep -qE 'Failed to deserialize|not found' i3status-rust.err; then
          cat i3status-rust.err >&2
          exit 1
        fi

        touch $out
      '';
in
pkgs.linkFarm "lint-desktop" (
  map (entry: {
    name = entry.themeName;
    path = checkTheme entry;
  }) rendered
)
