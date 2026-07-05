{ ... }: {
  imports = [ ../../common/home.nix ];
  domains.wm.i3.enable = true;
  domains.bar.i3status.enable = true;
  domains.launcher.rofi.enable = true;
  domains.session.x11.enable = true;
  domains.terminal.ghostty.enable = true;
}
