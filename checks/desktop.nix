{
  lib,
  pkgs,
  themesLib,
  renderDomainOutputFor,
  ftpMounts ? [ ],
}:

let
  themeNames = lib.attrNames themesLib.themes;
  hardwareMetrics = pkgs.callPackage ../domains/bar/i3status-rust/hardware-metrics.nix { };
  networkMetrics = pkgs.callPackage ../domains/bar/i3status-rust/network-metrics.nix { };
  cheatsheet = pkgs.callPackage ../domains/wm/i3/cheatsheet.nix { };
  ftpStatus = pkgs.callPackage ../domains/remote/ftp/status.nix {
    inherit lib;
    mounts = map (mountPoint: {
      inherit mountPoint;
      service = "angst-ftp-test";
    }) ftpMounts;
  };

  renderForTheme = themeName: {
    inherit themeName;
    themeBg = (themesLib.get themeName).palette.background.base;
    themeError = (themesLib.get themeName).ansi.error;
    themeWarn = (themesLib.get themeName).ansi.warn;
    i3Config = renderDomainOutputFor themeName "domains/wm/i3/config/config";
    cheatsheetConky = renderDomainOutputFor themeName "domains/wm/i3/config/cheatsheet.conky";
    networkMenuConky = renderDomainOutputFor themeName "domains/wm/i3/config/network-menu.conky";
    i3statusRustConfig = renderDomainOutputFor themeName "domains/bar/i3status-rust/config/config.toml";
    ghosttyConfig = renderDomainOutputFor themeName "domains/terminal/ghostty/config/config.ghostty";
    ghosttyColors = renderDomainOutputFor themeName "domains/terminal/ghostty/config/colors.conf";
  };

  rendered = map renderForTheme themeNames;

  checkTheme =
    {
      themeName,
      themeBg,
      themeError,
      themeWarn,
      i3Config,
      cheatsheetConky,
      networkMenuConky,
      i3statusRustConfig,
      ghosttyConfig,
      ghosttyColors,
    }:
    pkgs.runCommand "lint-desktop-${themeName}"
      {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.ghostty
          pkgs.gnugrep
          pkgs.i3
          pkgs.i3status-rust
          pkgs.jq
          hardwareMetrics
          networkMetrics
          cheatsheet
          ftpStatus
        ];
      }
      ''
        mkdir -p home/.config/i3
        cp ${pkgs.writeText "monitors-${themeName}.conf" ''
          exec --no-startup-id xrandr --output DP-1 --mode 1920x1080 --rate 144 --pos 0x0
          exec --no-startup-id xrandr --output HDMI-A-2 --mode 1920x1080 --rate 60 --pos 1920x0
        ''} home/.config/i3/monitors.conf
        cp ${pkgs.writeText "i3-${themeName}.conf" i3Config} i3.conf
        cp ${pkgs.writeText "cheatsheet-${themeName}.conky" cheatsheetConky} cheatsheet.conky
        cp ${pkgs.writeText "network-menu-${themeName}.conky" networkMenuConky} network-menu.conky
        cp ${pkgs.writeText "i3status-rust-${themeName}.toml" i3statusRustConfig} config.toml
        cp ${pkgs.writeText "ghostty-${themeName}.conf" ghosttyConfig} ghostty.conf
        cp ${pkgs.writeText "ghostty-colors-${themeName}.conf" ghosttyColors} colors.conf
        mkdir -p home/.config runtime

        echo "Validating i3 config for theme ${themeName}..."
        HOME="$PWD/home" i3 -C -c i3.conf
        if ! grep -qE "urgent_workspace[[:space:]]+#${themeError}[[:space:]]+#${themeError}" i3.conf; then
          echo "urgent workspace background did not use theme error color #${themeError}" >&2
          exit 1
        fi
        if ! grep -qF "workspace_command i3-workspace-group bar ${themeError}" i3.conf; then
          echo "workspace command did not use theme error color #${themeError} for urgent workspaces" >&2
          exit 1
        fi
        if ! grep -qF 'bindsym $mod+u exec --no-startup-id i3-workspace-group urgent' i3.conf; then
          echo "i3 config is missing the mod+u urgent bell binding" >&2
          exit 1
        fi
        if ! grep -qF 'bindsym $mod+Escape exec --no-startup-id i3-lock' i3.conf; then
          echo "i3 config is missing the mod+Escape lock binding" >&2
          exit 1
        fi
        if ! grep -qF 'bindsym --release $mod+i exec --no-startup-id i3-hardware-menu' i3.conf; then
          echo "i3 config is missing the mod+i hardware menu binding" >&2
          exit 1
        fi
        if ! grep -qF 'for_window [class="^i3-hardware-menu$"] floating enable, border none, sticky enable' i3.conf; then
          echo "i3 config is missing the hardware menu window rule" >&2
          exit 1
        fi
        if ! grep -qF 'bindsym --release $mod+n exec --no-startup-id i3-network-menu' i3.conf; then
          echo "i3 config is missing the mod+n network menu binding" >&2
          exit 1
        fi
        if ! grep -qF 'for_window [class="^i3-network-menu$"] floating enable, border none, sticky enable' i3.conf; then
          echo "i3 config is missing the network menu window rule" >&2
          exit 1
        fi
        if ! grep -qF 'bindsym --release $mod+Shift+slash exec --no-startup-id i3-cheatsheet toggle' i3.conf; then
          echo "i3 config is missing the mod+Shift+slash cheatsheet binding" >&2
          exit 1
        fi
        if ! grep -qF 'for_window [class="^i3-cheatsheet$"] floating enable, border none, move to workspace current, move position center' i3.conf; then
          echo "i3 config is missing the cheatsheet window rule" >&2
          exit 1
        fi
        if ! grep -qF "alignment = 'middle_middle'" cheatsheet.conky; then
          echo "cheatsheet conky config is not centered" >&2
          exit 1
        fi
        if ! grep -qF 'gap_y = -12' cheatsheet.conky; then
          echo "cheatsheet conky config does not account for the bar height" >&2
          exit 1
        fi
        if ! grep -qF 'no_focus [class="^i3-cheatsheet$"]' i3.conf; then
          echo "i3 config is missing the cheatsheet no_focus rule" >&2
          exit 1
        fi
        if ! grep -qF "own_window_class = 'i3-network-menu'" network-menu.conky; then
          echo "network menu conky config is missing its window class" >&2
          exit 1
        fi
        if ! grep -qF 'execpi 2 i3-network-metrics --details' network-menu.conky; then
          echo "network menu conky config is missing the details command" >&2
          exit 1
        fi
        HOME="$PWD/home" i3-cheatsheet generate "$PWD/i3.conf" > cheatsheet.txt
        for expected in 'Mod+?' 'WINDOWS' 'WORKSPACES' 'toggle shortcuts overlay' 'toggle network menu'; do
          if ! grep -qF "$expected" cheatsheet.txt; then
            echo "cheatsheet output is missing: $expected" >&2
            cat cheatsheet.txt >&2
            exit 1
          fi
        done

        echo "Validating Ghostty config for theme ${themeName}..."
        HOME="$PWD/home" XDG_CONFIG_HOME="$PWD/home/.config" ghostty +validate-config --config-file="$PWD/ghostty.conf"

        echo "Validating i3status-rust config for theme ${themeName}..."
        code=0
        XDG_RUNTIME_DIR="$PWD/runtime" timeout 6 i3status-rs "$PWD/config.toml" >status.json 2>i3status-rust.err || code=$?
        if [ "$code" -ne 0 ] && [ "$code" -ne 124 ]; then
          echo "i3status-rs exited unexpectedly (status $code)" >&2
          cat i3status-rust.err >&2
          exit 1
        fi
        if grep -qE 'Failed to deserialize|not found' i3status-rust.err; then
          cat i3status-rust.err >&2
          exit 1
        fi
        if ! grep -qF 'command = "i3-hardware-metrics"' config.toml; then
          echo "bar config is missing the hardware summary command" >&2
          exit 1
        fi
        if ! grep -qF "warning_bg = \"#${themeWarn}\"" config.toml; then
          echo "hardware summary warning background did not use theme warning color #${themeWarn}" >&2
          exit 1
        fi
        if ! grep -qF "critical_bg = \"#${themeError}\"" config.toml; then
          echo "hardware summary critical background did not use theme error color #${themeError}" >&2
          exit 1
        fi
        if ! grep -qF 'cmd = "sh -c' config.toml; then
          echo "hardware summary click handler is missing" >&2
          exit 1
        fi
        XDG_RUNTIME_DIR="$PWD/runtime" i3-hardware-metrics >metrics.json
        if ! grep -qE '^\{"text":"(CPU|RAM|DISK|GPU) [0-9]+%","state":"(Idle|Warning|Critical)"\}$' metrics.json; then
          echo "hardware summary returned unexpected output" >&2
          cat metrics.json >&2
          exit 1
        fi
        if ! grep -qF 'command = "i3-network-metrics"' config.toml; then
          echo "bar config is missing the network summary command" >&2
          exit 1
        fi
        if ! grep -qF 'format = " $icon "' config.toml; then
          echo "network bar block is not icon-only" >&2
          exit 1
        fi
        if ! grep -qF 'command -v i3-network-menu' config.toml; then
          echo "bar config is missing the network menu click handler" >&2
          exit 1
        fi
        XDG_RUNTIME_DIR="$PWD/runtime" i3-network-metrics >network.json
        if ! jq -e 'type == "object" and (.icon == "net_offline" or .icon == "net_wifi" or .icon == "net_wired" or .icon == "net_vpn") and .text == "" and (.state == "Idle" or .state == "Warning" or .state == "Critical")' network.json >/dev/null; then
          echo "network summary returned unexpected output" >&2
          cat network.json >&2
          exit 1
        fi
        XDG_RUNTIME_DIR="$PWD/runtime" i3-network-metrics --details >network-details.txt
        if ! grep -qF 'STATUS' network-details.txt || ! grep -qF 'TYPE' network-details.txt; then
          echo "network details returned unexpected output" >&2
          cat network-details.txt >&2
          exit 1
        fi

        ${lib.optionalString (ftpMounts != [ ]) ''
          if ! grep -qF 'command = "angst-ftp-status"' config.toml; then
            echo "bar config is missing the ftp status command" >&2
            exit 1
          fi
          if ! grep -qF 'cmd = "angst-ftp-status toggle"' config.toml; then
            echo "bar config is missing the ftp toggle click handler" >&2
            exit 1
          fi
          if ! grep -qF 'bindsym $mod+Shift+p exec --no-startup-id angst-ftp-status toggle' i3.conf; then
            echo "i3 config is missing the ftp toggle binding" >&2
            exit 1
          fi
          if ! grep -qF 'toggle ftp mount' cheatsheet.txt; then
            echo "cheatsheet is missing the ftp toggle label" >&2
            cat cheatsheet.txt >&2
            exit 1
          fi
          ftpOut=$(HOME="$PWD/home" angst-ftp-status)
          if [ "$ftpOut" != '{"icon":"net_down","state":"Idle","text":"ftp"}' ]; then
            echo "ftp status did not show an idle toggle when no mount is active" >&2
            echo "$ftpOut" >&2
            exit 1
          fi
        ''}

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
