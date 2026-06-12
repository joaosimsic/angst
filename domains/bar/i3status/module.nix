{ config, lib, pkgs, themesLib, renderTemplate, ... }:

let
  cfg = config.domains.bar.i3status;
  theme = themesLib.get config.theme;

  barBlock = renderTemplate {
    inherit lib;
    templatePath = ./bar.template;
    tokens = theme;
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.i3status ];

    domains.wm._i3.configLines = [ barBlock ];
  };
}
