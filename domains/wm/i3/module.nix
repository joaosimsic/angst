{ config, lib, themesLib, renderTemplate, monitors, ... }:

let
  cfg = config.domains.wm.i3;

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

  body = renderTemplate {
    inherit lib;
    templatePath = ./config/config.template;
    tokens = theme;
  };

  fragments = config.domains.wm._i3.configLines;

  i3Config = body + "\n" + lib.concatStringsSep "\n" fragments;
in
{
  config = lib.mkIf cfg.enable {
    xdg.configFile = {
      "i3/config".text = i3Config;
      "i3/monitors.conf".text = monitorsConf;
    };
  };
}
