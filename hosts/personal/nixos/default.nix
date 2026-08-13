{
  type = "nixos";
  system = "x86_64-linux";
  repoPath = "proj/angst";
  hostname = "nixos";
  username = "joao";
  theme = "miasma";
  profiles = [
    "base"
    "desktop"
    "development"
  ];
  toolchains = "*";

  monitors = {
    primary = {
      name = "DP-1";
      resolution = "1920x1080";
      refreshRate = 144;
      position = "0x0";
    };
  };

  db.connections = { };
  nixos = {
    keyboardLayout = "br-abnt2";
  };
  home = { };
  env = {
    EDITOR = "nvim";
    BROWSER = "firefox";
  };
  shell = "";

  sshAgent = {
    enable = true;
    keys = [ "~/.ssh/id_ed25519" ];
  };
  ssh = { };
  ftp = {
    mounts = [
      {
        mountPoint = "ftp/server";
      }
    ];
  };

  persist = {
    enable = true;
    root = "/persist";
    homeDirs = [
      ".mozilla"
      ".config/google-chrome"
      ".local/share/keyrings"
    ];
  };
  projects = [ ]; # opaque store ids (angst projects status); names stay encrypted
}
