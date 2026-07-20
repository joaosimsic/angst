{ mkDomainEnable, mkCap }:
{
  hm = [
    (mkDomainEnable "wm.i3")
    (mkDomainEnable "bar.i3status")
    (mkDomainEnable "launcher.rofi")
    (mkDomainEnable "terminal.ghostty")
    (mkDomainEnable "session.x11")
  ];
  nixos = [
    (mkCap "graphical")
    (mkCap "audio")
    (mkCap "clipboard")
  ];
}
