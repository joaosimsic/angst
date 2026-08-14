{
  type = "nixos";
  system = "x86_64-linux";
  hostname = "vm";
  username = "joao";
  theme = "miasma";
  profiles = [
    "base"
    "desktop"
    "development"
    "vm"
  ];
  toolchains = "*";

  monitors = { };

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
    keys = [
      "~/.ssh/id_ed25519"
      "~/.ssh/work_ed25519"
    ];
  };
  ssh = {
    hosts = [
      {
        host = "github.com";
        hostName = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
      }
      {
        host = "gitlab.com";
        hostName = "gitlab.com";
        user = "git";
        identityFile = "~/.ssh/work_ed25519";
      }
    ];
  };
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
      ".ssh"
      ".local/share"
      ".config"
      ".cache"
    ];
  };
  projects = [
    "7391b51c36a7d266"
  ]; # opaque store ids (angst projects status); names stay encrypted
}
