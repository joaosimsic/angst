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
  xrandrLine = lib.optionalString (m ? name && m ? resolution) ''
    ${pkgs.xrandr}/bin/xrandr --output ${m.name} \
      --mode ${m.resolution} \
      --rate ${toString (m.refreshRate or 60)} \
      --pos ${m.position or "0x0"}
  '';
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
