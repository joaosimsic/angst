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
  isHost = role == "host" || role == "both";

  moonlight =
    if config.lib ? nixGL then config.lib.nixGL.wrap pkgs.moonlight-qt else pkgs.moonlight-qt;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = lib.optional isClient moonlight;

    home.activation.angstSunshineHost = lib.mkIf isHost (
      lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
        ${pkgs.systemd}/bin/systemctl --user start --no-block sunshine.service || true
      ''
    );
  };
}
