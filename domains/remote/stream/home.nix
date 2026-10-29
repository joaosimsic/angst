{
  config,
  lib,
  pkgs,
  hostType,
  ...
}:

let
  cfg = config.domains.remote.stream;

  moonlight =
    if config.lib ? nixGL then config.lib.nixGL.wrap pkgs.moonlight-qt else pkgs.moonlight-qt;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (hostType != "nixos") moonlight;
  };
}
