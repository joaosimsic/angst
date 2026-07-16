{ ... }: {
  imports = [ ../../common/home.nix ];
  domains = {
    wm.i3.enable = true;
    bar.i3status.enable = true;
    launcher.rofi.enable = true;
    session.x11.enable = true;
    terminal.ghostty.enable = true;
  };
}
