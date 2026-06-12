{ config, lib, pkgs, themesLib, renderTemplate, templateTokens, ... }:

let
  cfg = config.domains.bar.i3status;

  tokens = templateTokens {
    inherit lib themesLib;
    theme = config.theme;
    fontFamily = config.font.family;
  };

  barBlock = renderTemplate {
    inherit lib;
    templatePath = ./bar.template;
    inherit tokens;
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.i3status ];

    domains.wm._i3.configLines = [ barBlock ];
  };
}
