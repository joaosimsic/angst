{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.kernel.network;
in
{
  options.domains.kernel.network = {
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
