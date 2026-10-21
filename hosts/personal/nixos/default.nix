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
    "design"
    "embedded"
    "game-dev"
    "office"
    "gaming"
    "obs"
    "vpn"
  ];
  toolchains = "*";

  monitors = {
    primary = {
      name = "DP-1";
      resolution = "1920x1080";
      refreshRate = 144;
      position = "0x0";
    };
    secondary = {
      name = "HDMI-2";
      resolution = "1920x1080";
      refreshRate = 60;
      position = "1920x0";
    };
  };

  db = [ "work/intelligence" ];

  nixos = {
    keyboardLayout = "br-abnt2";
    virtualisation.docker.daemon.settings.data-root = "/home/docker-data";
    domains.network.vpn.openvpn.servers.us = {
      config = "config /run/secrets/vpn/us.ovpn";
      authUserPass = "/run/secrets/vpn/us.creds";
      updateResolvConf = true;
      autoStart = false;
    };
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
      {
        host = "gitlab.ezvoice.com.br";
        hostName = "gitlab.ezvoice.com.br";
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
    root = "/state";
    dataRoot = "/home/durable";
  };
  projects = [
    "angst"
    "advent-of-code"
    "boring"
    "stealing-eye"
    "datapath"
    "llm-ruler"
    "agent"
    "horror"
    "Throughput"
    "Throughput-Releases"
    "vault"
    "TCC"
    "box"
    "intelligence/backend"
    "intelligence/frontend"
  ];
  secrets = [
    "opencode-go-key"
    "cursor-api-key"
  ];
  git = {
    personal = {
      name = "joaosimsic";
      email = "jpsimsic@hotmail.com";
    };
    work = {
      name = "joaosimsic";
      email = "joao.simsic@ezvoice.com.br";
    };
  };
}
