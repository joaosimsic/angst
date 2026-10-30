{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.kernel.audio;
in
{
  options.domains.kernel.audio = {
    enable = lib.mkEnableOption "System audio processing via Pipewire";
  };

  config = lib.mkIf cfg.enable {
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      wireplumber.extraConfig."10-default-volume" = {
        "wireplumber.settings" = {
          "device.routes.default-sink-volume" = 1.0;
        };
      };
    };

    environment.systemPackages = [
      pkgs.pavucontrol
      pkgs.wireplumber
    ];
  };
}
