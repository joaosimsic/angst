{ mkDomainEnable }:
{
  hm = [
    (mkDomainEnable "wm.i3")
    (mkDomainEnable "bar.i3status")
    (mkDomainEnable "launcher.rofi")
    (mkDomainEnable "terminal.ghostty")
    (mkDomainEnable "session.x11")
  ];
  nixos = [
    ({ ... }: {
      capabilities.graphical.enable = true;
      capabilities.audio.enable = true;
      capabilities.clipboard.enable = true;
    })
    ../../capabilities/graphical.nix
    ../../capabilities/audio.nix
    ../../capabilities/clipboard.nix
  ];
}
