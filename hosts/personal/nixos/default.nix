{
  type = "nixos";
  system = "x86_64-linux";
  hostname = "nixos";
  username = "joao";
  theme = "miasma";
  profiles = [
    "base"
    "desktop"
    "development"
    "embedded"
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
    keys = [
      "~/.ssh/id_ed25519"
      "~/.ssh/work_ed25519"
    ];
  };
  ssh = {
    hosts = [
      {
        host = "work_server";
        hostName = "200.152.183.154";
        user = "joao";
        identityFile = "~/.ssh/work_ed25519";
        extraOptions = {
          SendEnv = "-TERM -LANG -LC_*";
        };
      }
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
        remotePath = "/httpdocs";
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
      ".arduino15"
    ];
  };
  projects = [
    "angst"
    "agent"
    "intelligence/backend"
    "intelligence/frontend"
  ];
}
