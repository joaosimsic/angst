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
  vpnStatus = pkgs.callPackage ../domains/bar/i3status-rust/vpn-status.nix { };
  servicesSeparator = pkgs.callPackage ../domains/bar/i3status-rust/services-separator.nix { };
  popoverClose = pkgs.callPackage ../domains/wm/i3/popover-close.nix { };
  popoverGuard = pkgs.callPackage ../domains/wm/i3/popover-guard.nix { inherit popoverClose; };
  cheatsheet = pkgs.callPackage ../domains/wm/i3/cheatsheet.nix { inherit popoverGuard; };
  toggles = pkgs.callPackage ../domains/wm/i3/toggles.nix { };
  togglesMenu = pkgs.callPackage ../domains/wm/i3/toggles-menu.nix { inherit popoverGuard; };
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
    themeBgVariant = (themesLib.get themeName).palette.background.variant;
    themeError = (themesLib.get themeName).ansi.error;
    themeWarn = (themesLib.get themeName).ansi.warn;
    i3Config = renderDomainOutputFor themeName "domains/wm/i3/config/config";
    cheatsheetConky = renderDomainOutputFor themeName "domains/wm/i3/config/cheatsheet.conky";
    networkMenuConky = renderDomainOutputFor themeName "domains/wm/i3/config/network-menu.conky";
    togglesMenuConky = renderDomainOutputFor themeName "domains/wm/i3/config/toggles-menu.conky";
    i3statusRustConfig = renderDomainOutputFor themeName "domains/bar/i3status-rust/config/config.toml";
    ghosttyConfig = renderDomainOutputFor themeName "domains/terminal/ghostty/config/config.ghostty";
    ghosttyColors = renderDomainOutputFor themeName "domains/terminal/ghostty/config/colors.conf";
  };

  rendered = map renderForTheme themeNames;

  checkTheme =
    {
      themeName,
      themeBg,
      themeBgVariant,
      themeError,
      themeWarn,
      i3Config,
      cheatsheetConky,
      networkMenuConky,
      togglesMenuConky,
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
          vpnStatus
          servicesSeparator
          cheatsheet
          toggles
          togglesMenu
          popoverClose
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
        cp ${pkgs.writeText "toggles-menu-${themeName}.conky" togglesMenuConky} toggles-menu.conky
        cp ${pkgs.writeText "i3status-rust-${themeName}.toml" i3statusRustConfig} config.toml
        cp ${pkgs.writeText "ghostty-${themeName}.conf" ghosttyConfig} ghostty.conf
        cp ${pkgs.writeText "ghostty-colors-${themeName}.conf" ghosttyColors} colors.conf
        mkdir -p home/.config runtime

        sleep 60 &
        popover_pid=$!
        printf '%s\n' "$popover_pid" > runtime/i3-toggles-menu.pid
        XDG_RUNTIME_DIR="$PWD/runtime" i3-popover-close
        wait "$popover_pid" 2>/dev/null || true
        if kill -0 "$popover_pid" 2>/dev/null; then
          echo "i3-popover-close did not terminate the overlay process" >&2
          exit 1
        fi
        if [ -e runtime/i3-toggles-menu.pid ]; then
          echo "i3-popover-close did not remove the overlay pidfile" >&2
          exit 1
        fi

        echo "Validating i3 config for theme ${themeName}..."
        HOME="$PWD/home" i3 -C -c i3.conf
        if ! grep -qE "urgent_workspace[[:space:]]+#${themeError}[[:space:]]+#${themeError}" i3.conf; then
          echo "urgent workspace background did not use theme error color #${themeError}" >&2
          exit 1
        fi
        if ! grep -qE "workspace_command .*i3-workspace-group bar ${themeError}" i3.conf; then
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
        if ! grep -qF 'bindsym --release $mod+Shift+t exec --no-startup-id i3-toggles-menu' i3.conf; then
          echo "i3 config is missing the mod+Shift+t toggles menu binding" >&2
          exit 1
        fi
        if ! grep -qF 'bindsym $mod+Shift+v exec --no-startup-id i3-toggles toggle work-vpn' i3.conf; then
          echo "i3 config is missing the work VPN toggle binding" >&2
          exit 1
        fi
        if ! grep -qF 'bindsym $mod+Shift+g exec --no-startup-id i3-toggles toggle sunshine' i3.conf; then
          echo "i3 config is missing the Sunshine toggle binding" >&2
          exit 1
        fi
        if ! grep -qF 'for_window [class="^i3-toggles-menu$"] floating enable, border none, move to workspace current, move position center' i3.conf; then
          echo "i3 config is missing the toggles menu window rule" >&2
          exit 1
        fi
        if ! grep -qF 'no_focus [class="^i3-toggles-menu$"]' i3.conf; then
          echo "i3 config is missing the toggles menu no_focus rule" >&2
          exit 1
        fi
        if ! grep -qF "own_window_class = 'i3-toggles-menu'" toggles-menu.conky; then
          echo "toggles menu conky config is missing its window class" >&2
          exit 1
        fi
        if ! grep -qF 'execpi 1 i3-toggles status' toggles-menu.conky; then
          echo "toggles menu conky config is missing the status command" >&2
          exit 1
        fi
        i3-toggles status > toggles.txt
        if ! grep -qF 'WORK VPN' toggles.txt || ! grep -qF 'SUNSHINE' toggles.txt; then
          echo "i3-toggles status returned unexpected output" >&2
          cat toggles.txt >&2
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
        for expected in 'Mod+?' 'WINDOWS' 'WORKSPACES' 'toggle shortcuts overlay' 'toggle network menu' 'toggle services panel' 'toggle work vpn' 'toggle sunshine'; do
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
        if ! jq -e 'type == "object" and (.icon == "net_offline" or .icon == "net_wifi" or .icon == "net_wired") and .text == "" and (.state == "Idle" or .state == "Warning" or .state == "Critical")' network.json >/dev/null; then
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
        if ! grep -qF 'command = "i3-vpn-status"' config.toml; then
          echo "bar config is missing the VPN service command" >&2
          exit 1
        fi
        if ! grep -qF 'cmd = "i3-toggles toggle work-vpn"' config.toml; then
          echo "bar config is missing the VPN toggle click handler" >&2
          exit 1
        fi
        if ! grep -qF 'format = " $icon $text "' config.toml; then
          echo "VPN bar block is not showing the active VPN name" >&2
          exit 1
        fi
        if ! grep -qF 'command = "i3-services-separator"' config.toml; then
          echo "bar config is missing the service section separator" >&2
          exit 1
        fi
        if grep -qF 'merge_with_next = false' config.toml; then
          echo "service blocks still disable grouping" >&2
          exit 1
        fi
        if ! grep -qF "idle_bg = \"#${themeBgVariant}\"" config.toml; then
          echo "service blocks did not use the theme variant background #${themeBgVariant}" >&2
          exit 1
        fi
        merge_count=$(grep -c 'merge_with_next = true' config.toml || true)
        if [ "$merge_count" -lt 4 ]; then
          echo "service blocks are not merged into a single group" >&2
          exit 1
        fi
        hide_count=$(grep -c 'hide_when_empty = true' config.toml || true)
        if [ "$hide_count" -lt 5 ]; then
          echo "service blocks do not hide when inactive" >&2
          exit 1
        fi
        vpn_line=$(grep -n 'command = "i3-vpn-status"' config.toml | head -1 | cut -d: -f1)
        sunshine_line=$(grep -n 'command = "i3-sunshine-status"' config.toml | head -1 | cut -d: -f1)
        mouse_line=$(grep -n 'command = "i3-mouse-hide status"' config.toml | head -1 | cut -d: -f1)
        separator_line=$(grep -n 'command = "i3-services-separator"' config.toml | head -1 | cut -d: -f1)
        hardware_line=$(grep -n 'command = "i3-hardware-metrics"' config.toml | head -1 | cut -d: -f1)
        if [ "$vpn_line" -ge "$hardware_line" ] || [ "$sunshine_line" -ge "$hardware_line" ] || [ "$mouse_line" -ge "$hardware_line" ]; then
          echo "service blocks are not left of the host info blocks" >&2
          exit 1
        fi
        if [ "$separator_line" -le "$mouse_line" ] || [ "$separator_line" -ge "$hardware_line" ]; then
          echo "service separator is not between services and host info" >&2
          exit 1
        fi
        vpnOut=$(i3-vpn-status)
        if ! jq -e 'type == "object" and .icon == "" and .text == "" and .state == "Idle"' <<< "$vpnOut" >/dev/null; then
          echo "VPN status did not hide when the service is inactive" >&2
          echo "$vpnOut" >&2
          exit 1
        fi
        separatorOut=$(i3-services-separator)
        if ! jq -e 'type == "object" and .text == "" and .state == "Idle"' <<< "$separatorOut" >/dev/null; then
          echo "service separator did not hide when no service is active" >&2
          echo "$separatorOut" >&2
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
          if [ "$ftpOut" != '{"icon":"","state":"Idle","text":""}' ]; then
            echo "ftp status did not hide when no mount is active" >&2
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
