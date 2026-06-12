{ lib, pkgs, themesLib, renderTemplate, domainsPath }:

let
  fontsLib = import ./fonts.nix;
  templateTokens = import ./templateTokens.nix;

  themeNames = lib.attrNames themesLib.themes;

  renderForTheme =
    themeName:
    let
      tokens = templateTokens {
        inherit themesLib;
        theme = themeName;
        fontFamily = fontsLib.defaultFamily;
      };

      i3Body = renderTemplate {
        inherit lib;
        templatePath = "${domainsPath}/wm/i3/config/config.template";
        inherit tokens;
      };

      barBlock = renderTemplate {
        inherit lib;
        templatePath = "${domainsPath}/bar/i3status/bar.template";
        inherit tokens;
      };

      fixtureFragments = [
        "bindsym $mod+Return exec ghostty"
        "bindsym $mod+Shift+Return exec ghostty"
        "bindsym $mod+d exec rofi -show drun"
        barBlock
        "exec_always --no-startup-id hsetroot -solid '#${tokens.BG}'"
        "exec --no-startup-id dbus-update-activation-environment --systemd --all"
        "exec --no-startup-id systemctl --user import-environment DISPLAY XAUTHORITY"
      ];
    in
    {
      inherit themeName;
      i3Config = i3Body + "\n" + lib.concatStringsSep "\n" fixtureFragments;
      i3statusConfig = renderTemplate {
        inherit lib;
        templatePath = "${domainsPath}/bar/i3status/config/config.template";
        inherit tokens;
      };
    };

  rendered = map renderForTheme themeNames;

  checkTheme =
    { themeName, i3Config, i3statusConfig }:
    pkgs.runCommand "lint-desktop-${themeName}" {
      nativeBuildInputs = [
        pkgs.coreutils
        pkgs.i3
        pkgs.i3status
      ];
    } ''
      mkdir -p home/.config/i3
      cp ${pkgs.writeText "monitors-${themeName}.conf" ''
        exec --no-startup-id xrandr --output DP-1 --mode 1920x1080 --rate 144 --pos 0x0
        exec --no-startup-id xrandr --output HDMI-A-2 --mode 1920x1080 --rate 60 --pos 1920x0
      ''} home/.config/i3/monitors.conf
      cp ${pkgs.writeText "i3-${themeName}.conf" i3Config} i3.conf
      cp ${pkgs.writeText "i3status-${themeName}.conf" i3statusConfig} i3status.conf

      echo "Validating i3 config for theme ${themeName}..."
      HOME="$PWD/home" i3 -C -c i3.conf

      echo "Validating i3status config for theme ${themeName}..."
      timeout 2 i3status -c i3status.conf >/dev/null || test $? -eq 124

      touch $out
    '';
in
pkgs.linkFarm "lint-desktop" (
  map (entry: {
    name = entry.themeName;
    path = checkTheme entry;
  }) rendered
)
