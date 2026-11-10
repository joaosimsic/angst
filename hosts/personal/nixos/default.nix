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
    "remote"
    "vpn"
  ];
  toolchains = "*";
  remoteStream = {
    role = "both";
  };

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
    imports = [ ./display-edid.nix ];
    keyboardLayout = "br-abnt2";
    angst.wakeOnLan = {
      enable = true;
      mac = "34:5a:60:a3:01:ec";
      interface = "enp42s0";
    };
    virtualisation.docker.daemon.settings.data-root = "/home/docker-data";
    domains.network.vpn.openvpn.servers.us = {
      config = "config /run/secrets/vpn/us.ovpn";
      authUserPass = "/run/secrets/vpn/us.creds";
      updateResolvConf = true;
      autoStart = false;
    };
    domains.network.vpn.openvpn.servers.cvx = {
      config = ''
        config /run/secrets/vpn/cvx.ovpn
        data-ciphers AES-256-CBC
        data-ciphers-fallback AES-256-CBC
        compat-mode 2.4.0
      '';
      authUserPass = "/run/secrets/vpn/cvx.creds";
      updateResolvConf = true;
      autoStart = true;
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
    "datapath"
    "llm-ruler"
    "agent"
    "threefold"
    "Throughput"
    "Throughput-Releases"
    "vault"
    "TCC"
    "TiConnect"
    "TiCrafter"
    "TicoTron"
    "box"
    "intelligence/backend"
    "intelligence/frontend"
  ];
  secrets = {
    scopes = [
      "personal"
      "work"
    ];
    password = "main";
    apps = [
      "personal/opencode-go-key"
      "work/cursor-api-key"
    ];
    host = [
      "personal/sunshine"
      "personal/tailscale"
    ];
  };
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
