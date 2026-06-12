{ config, lib, themesLib, renderTemplate, monitors, templateTokens, ... }:

let
  cfg = config.domains.wm.i3;

  tokens = templateTokens {
    inherit themesLib;
    theme = config.theme;
    fontFamily = config.font.family;
  };

  monitorOrder = lib.unique (
    lib.filter (n: lib.hasAttr n monitors) (
      [ "primary" "secondary" ] ++ lib.attrNames monitors
    )
  );

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
    inherit tokens;
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
