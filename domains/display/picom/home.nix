{
  config,
  lib,
  pkgs,
  hostname,
  ...
}:

let
  cfg = config.domains.display.picom;
  isVm = hostname == "vm";
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
      backend = if isVm then "xrender" else "glx";
      vSync = !isVm;
      settings = {
        shadow = false;
        fading = false;
        blur-background = !isVm;
        blur-method = "dual_kawase";
        blur-strength = 6;
        blur-background-fixed = true;
        blur-background-exclude = [ "class_g = 'slop'" ];
        detect-client-opacity = true;
        opacity-rule = [
          "45:class_g = 'i3-drag'"
          "100:class_g = 'slop'"
        ];
        corner-radius-rules = [ "4:class_g = 'i3-drag'" ];
      };
    };
  })
]
