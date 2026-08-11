{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.system.network;
in
{
  options.domains.system.network = {
    enable = lib.mkEnableOption "Basic networking tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      wget
      curl
      unzip
    ];
  };
}
