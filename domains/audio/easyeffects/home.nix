{
  config,
  lib,
  ...
}:

let
  cfg = config.domains.audio.easyeffects;
in
{
  config = lib.mkIf cfg.enable {
    services.easyeffects = {
      enable = true;
      preset = {
        output = "angst";
      };
      extraPresets.angst.output = import ./preset.nix;
    };
  };
}
