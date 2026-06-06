{ config, lib, pkgs, ... }:

let
  cfg = config.capabilities.network;
in
{
  options.capabilities.network = {
    enable = lib.mkEnableOption "Basic networking tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      wget
      curl
    ];
  };
}