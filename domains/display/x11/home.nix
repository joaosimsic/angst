{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.display.x11;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || config.domains.system.graphical.enable;
          message = "domains.display.x11 requires domains.system.graphical to be enabled";
        }
      ];
    }
    (lib.mkIf cfg.enable {
      home.packages = with pkgs; [
        hsetroot
      ];
    })
  ];
}
