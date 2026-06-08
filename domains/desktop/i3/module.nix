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
      pos = lib.splitString "x" m.position;
      x = builtins.elemAt pos 0;
      y = builtins.elemAt pos 1;
    in
    "output ${m.name} mode ${m.resolution} --refresh ${toString m.refreshRate} position ${x} ${y}";

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
      xclip
      networkmanagerapplet
    ];

    xdg.configFile = {
      "i3/monitors.conf".text = monitorsConf;

      "i3status/config".text = renderTemplate {
        inherit lib;
        templatePath = ./i3status.template;
        tokens = theme;
      };
    };
  };
}
