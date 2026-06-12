{ config, lib, userConfig, ... }:

let
  hmUser = config.home-manager.users.${userConfig.username} or { };
  enabled = hmUser.domains.wm.i3.enable or false;
in
{
  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = !enabled || config.capabilities.graphical.enable;
        message = "domains.wm.i3 requires capabilities.graphical to be enabled";
      }
    ];

    services.xserver.windowManager.i3.enable = true;
  };
}
