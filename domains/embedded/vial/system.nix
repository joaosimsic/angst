{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.embedded.vial;
in
{
  options.domains.embedded.vial = {
    enable = lib.mkEnableOption "Vial keyboard configurator";
  };

  config = lib.mkIf cfg.enable {
    services.udev.packages = [ pkgs.vial ];
    hardware.keyboard.qmk.enable = true;
  };
}
