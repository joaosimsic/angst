{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.games.minecraft;
in
{
  options.domains.games.minecraft.enable = lib.mkEnableOption "Minecraft LAN server access";

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 25565 ];

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "java8" ''
        exec ${pkgs.jdk8}/bin/java "$@"
      '')
    ];
  };
}
