{
  config,
  lib,
  pkgs,
  theme,
  themesLib,
  monitors,
  ...
}:

let
  cfg = config.domains.display.x11;
  t = themesLib.get theme;
  p = t.palette;
  gtkTheme = if t.isDark then "Adwaita:dark" else "Adwaita";
  m = monitors.primary or { };
  xrandrLine =
    if m ? name && m ? resolution then
      if m.resolution == "auto" then
        ''
          ${pkgs.xrandr}/bin/xrandr --output ${m.name} \
            --auto \
            --pos ${m.position or "0x0"}
        ''
      else if m.resolution == "kernel" then
        ''
          res=""
          for arg in $(${pkgs.coreutils}/bin/cat /proc/cmdline); do
            case "$arg" in
              video=${m.name}:*)
                res="''${arg#video=${m.name}:}"
                res="''${res%@*}"
                ;;
            esac
          done
          if [ -n "$res" ]; then
            ${pkgs.xrandr}/bin/xrandr --output ${m.name} \
              --mode "$res" \
              --rate ${toString (m.refreshRate or 60)} \
              --pos ${m.position or "0x0"}
          fi
        ''
      else
        ''
          ${pkgs.xrandr}/bin/xrandr --output ${m.name} \
            --mode ${m.resolution} \
            --rate ${toString (m.refreshRate or 60)} \
            --pos ${m.position or "0x0"}
        ''
    else
      "";
in
{
  options.domains.display.x11 = {
    enable = lib.mkEnableOption "X11 session autostart";

    windowManager = lib.mkOption {
      type = lib.types.package;
      default = pkgs.i3;
      description = "Window manager launched by the angst X11 session";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.domains.kernel.graphical.enable;
        message = "domains.display.x11 requires domains.kernel.graphical to be enabled";
      }
    ];

    services.xserver.displayManager.session = [
      {
        manage = "desktop";
        name = "i3";
        start = ''
          #!${pkgs.bash}/bin/sh

          export GTK_THEME="${gtkTheme}"
          export SAL_USE_VCLPLUGIN=gtk3
          export QT_QPA_PLATFORMTHEME=kde
          export QT_STYLE_OVERRIDE=breeze

          ${xrandrLine}

          ${pkgs.hsetroot}/bin/hsetroot -solid "#${p.background.base}"

          exec ${lib.getExe cfg.windowManager}
        '';
      }
    ];
  };
}
