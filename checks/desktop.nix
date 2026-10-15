{
  lib,
  pkgs,
  themeSys,
  renderDomainOutputFor,
}:

let
  themeNames = lib.attrNames themeSys.themes;

  renderForTheme = themeName: {
    inherit themeName;
    themeBg = (themeSys.get themeName).palette.background.base;
    i3Config = renderDomainOutputFor themeName "domains/wm/i3/config/config";
    i3statusRustConfig = renderDomainOutputFor themeName "domains/bar/i3status-rust/config/config.toml";
  };

  rendered = map renderForTheme themeNames;

  checkTheme =
    {
      themeName,
      themeBg,
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
        code=0
        timeout 6 i3status-rs "$PWD/config.toml" >status.json 2>i3status-rust.err || code=$?
        if [ "$code" -ne 0 ] && [ "$code" -ne 124 ]; then
          echo "i3status-rs exited unexpectedly (status $code)" >&2
          cat i3status-rust.err >&2
          exit 1
        fi
        if grep -qE 'Failed to deserialize|not found' i3status-rust.err; then
          cat i3status-rust.err >&2
          exit 1
        fi

        echo "Checking rendered bar output for theme ${themeName}..."
        if ! grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}' status.json; then
          echo "time block did not render a formatted date; format placeholders are not substituted" >&2
          cat status.json >&2
          exit 1
        fi
        if grep -q '%Y' status.json; then
          echo "time block rendered raw strftime placeholders" >&2
          exit 1
        fi
        if ! grep -q "#${lib.toUpper themeBg}FF" status.json; then
          echo "bar blocks did not use the theme background #${themeBg}" >&2
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
