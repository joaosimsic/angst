{
  config,
  lib,
  pkgs,
  host,
  ...
}:

let
  cfg = config.domains.remote.stream;
  role = host.remoteStream.role;
  isClient = role == "client" || role == "both";

  moonlight =
    if config.lib ? nixGL then config.lib.nixGL.wrap pkgs.moonlight-qt else pkgs.moonlight-qt;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = lib.optional isClient moonlight;
  };
}
