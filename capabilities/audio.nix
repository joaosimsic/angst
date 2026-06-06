{ config, lib, pkgs, ... }:

let
  cfg = config.capabilities.audio;
in
{
  options.capabilities.audio = {
    enable = lib.mkEnableOption "System audio processing via Pipewire";
  };

  config = lib.mkIf cfg.enable {
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    
    environment.systemPackages = [ pkgs.pavucontrol ];
  };
}
