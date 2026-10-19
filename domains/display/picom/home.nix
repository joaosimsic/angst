{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.display.picom;
in
lib.mkMerge [
  {
    assertions = [
      {
        assertion = !cfg.enable || config.domains.kernel.graphical.enable;
        message = "domains.display.picom requires domains.kernel.graphical to be enabled";
      }
    ];
  }
  (lib.mkIf cfg.enable {
    services.picom = {
      enable = true;
      package = config.lib.nixGL.wrap pkgs.picom;
      backend = "glx";
      vSync = true;
      settings = {
        shadow = false;
        fading = false;
        blur-background = true;
        blur-method = "dual_kawase";
        blur-strength = 6;
        blur-background-fixed = true;
      };
    };
  })
]
