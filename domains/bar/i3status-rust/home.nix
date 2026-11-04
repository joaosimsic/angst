{
  config,
  lib,
  pkgs,
  host,
  ...
}:

let
  cfg = config.domains.bar.i3status-rust;
  isSunshineHost = host.remoteStream.role == "host" || host.remoteStream.role == "both";
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.callPackage ./hardware-metrics.nix { })
      (pkgs.callPackage ./network-metrics.nix { })
    ]
    ++ lib.optional isSunshineHost (pkgs.callPackage ./sunshine-status.nix { });
  };
}
