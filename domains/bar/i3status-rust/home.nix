{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.bar.i3status-rust;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.callPackage ./hardware-metrics.nix { })
    ];
  };
}
