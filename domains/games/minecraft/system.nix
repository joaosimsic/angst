{
  config,
  lib,
  ...
}:

let
  cfg = config.domains.games.minecraft;
in
{
  options.domains.games.minecraft.enable = lib.mkEnableOption "Minecraft LAN server access";

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 25565 ];
  };
}
