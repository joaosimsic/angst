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
          assertion = !cfg.enable || config.domains.kernel.graphical.enable;
          message = "domains.display.x11 requires domains.kernel.graphical to be enabled";
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
