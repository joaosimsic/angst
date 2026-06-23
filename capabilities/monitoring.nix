{ config, lib, pkgs, ... }:

let
  cfg = config.capabilities.monitoring;
in
{
  options.capabilities.monitoring = {
    enable = lib.mkEnableOption "Monitoring tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      btop
    ];
  };
}

