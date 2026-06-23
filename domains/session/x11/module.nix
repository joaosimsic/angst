{ config, lib, pkgs, themesLib, ... }:

let
  cfg = config.domains.session.x11;
  theme = themesLib.get config.theme;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      hsetroot
      xclip
    ];

    domains.wm._i3.configLines = [
      "exec_always --no-startup-id ${pkgs.hsetroot}/bin/hsetroot -solid '#${theme.BG}'"
      "exec --no-startup-id dbus-update-activation-environment --systemd --all"
      "exec --no-startup-id systemctl --user import-environment DISPLAY XAUTHORITY PATH XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS"
      "exec --no-startup-id systemctl --user start graphical-session.target"
    ];
  };
}
