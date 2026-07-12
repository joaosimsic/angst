{
  system = "x86_64-linux";

  theme = "github";

  repoPath = "proj/angst";

  user = import ../../common/user.nix;

  monitors = {
    primary = {
      name = "DP-1";
      resolution = "1920x1080";
      refreshRate = 144;
      position = "0x0";
    };

    secondary = {
      name = "HDMI-A-2";
      resolution = "1920x1080";
      refreshRate = 60;
      position = "1920x0";
    };
  };
}
