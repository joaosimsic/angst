{ config, lib, pkgs, themesLib, renderTemplate, monitors, ... }:

let
  cfg = config.domains.desktop.i3;

  theme = themesLib.get config.theme;

  monitorOrder =
    [ "primary" "secondary" ]
    ++ lib.filter (n: n != "primary" && n != "secondary") (lib.attrNames monitors);

  monitorLine =
    name:
    let
      m = monitors.${name};
    in
    "exec --no-startup-id xrandr --output ${m.name} --mode ${m.resolution} --rate ${toString m.refreshRate} --pos ${m.position}";

  monitorsConf =
    if monitors == { } then
      "# no monitor overrides configured"
    else
      lib.concatStringsSep "\n" (map monitorLine monitorOrder);
in
{
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      rofi
      i3status
      hsetroot
      xclip
      networkmanagerapplet
    ];

    xdg.configFile = {
      "i3/config".text = renderTemplate {
        inherit lib;
        templatePath = ./config/config.template;
        tokens = theme;
      };

      "i3/monitors.conf".text = monitorsConf;

      "i3status/config".text = renderTemplate {
        inherit lib;
        templatePath = ./i3status.template;
        tokens = theme;
      };
    };
  };
}
