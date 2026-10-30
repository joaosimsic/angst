{
  config,
  lib,
  pkgs,
  store,
  ...
}:

let
  cfg = config.domains.kernel.graphical;
  inherit (store) hasWayland;
in
{
  options.domains.kernel.graphical = {
    enable = lib.mkEnableOption "Graphical desktop with X11";
  };

  config = lib.mkIf cfg.enable {
    services = {
      xserver = {
        enable = true;
        serverFlagsSection = ''
          Option "BlankTime" "0"
          Option "StandbyTime" "0"
          Option "SuspendTime" "0"
          Option "OffTime" "0"
        '';
      };
      libinput.enable = true;
      dbus.enable = true;
      logind.settings.Login.IdleAction = "ignore";
    };

    boot.kernelParams = [ "consoleblank=0" ];

    xdg.portal = {
      enable = true;
      extraPortals =
        with pkgs;
        [ xdg-desktop-portal-gtk ] ++ lib.optionals hasWayland [ xdg-desktop-portal-wlr ];
      config.common.default = "*";
    };

    environment.systemPackages = with pkgs; [
      xrandr
      xset
    ];
  };
}
