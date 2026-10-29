{
  type = "nixos";
  system = "x86_64-linux";
  hostname = "work";
  username = "joao";
  theme = "miasma";
  profiles = [
    "base"
    "desktop"
    "development"
    "design"
    "game-dev"
    "office"
  ];
  toolchains = "*";

  monitors = {
    primary = {
      name = "HDMI-0";
      resolution = "1920x1080";
      refreshRate = 60;
      position = "0x0";
    };
    secondary = {
      name = "VGA-0";
      resolution = "1920x1080";
      refreshRate = 60;
      position = "1920x0";
    };
  };

  db = [ "work/intelligence" ];

  nixos =
    { config, ... }:
    {
      keyboardLayout = "br-abnt2";
      virtualisation.docker.daemon.settings.data-root = "/home/docker-data";
      domains.network.vpn.openvpn.servers.us = {
        config = "config /run/secrets/vpn/us.ovpn";
        authUserPass = "/run/secrets/vpn/us.creds";
        updateResolvConf = true;
        autoStart = false;
      };

      # Intel i5-7400 + NVIDIA GT 710 (Fermi/Kepler legacy branch).
      # If the 470 driver fails against a newer kernel, drop the nvidia
      # block and fall back to Intel HD 630 (modesetting) instead.
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware = {
        graphics.enable = true;
        nvidia = {
          package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
          modesetting.enable = true;
          open = false;
        };
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
  # ftp = {
  #   mounts = [
  #     {
  #       mountPoint = "ftp/server";
  #       remotePath = "/httpdocs";
  #     }
  #   ];
  # };

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
    "threefold"
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
