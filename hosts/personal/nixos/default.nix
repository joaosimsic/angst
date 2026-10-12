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
    "vm"
    "game-dev"
    "office"
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

  db = [ "work/intelligence" ];

  nixos = {
    keyboardLayout = "us";
    virtualisation.docker.daemon.settings.data-root = "/home/docker-data";
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
    root = "/persist";
    homeDirs = [
      ".ssh"
      ".mozilla"
      ".cursor"
      ".docker"
      ".kube"
      ".arduino15"
      "Arduino"
      ".config/google-chrome"
      ".config/easyeffects"
      ".config/discord"
      ".config/libreoffice"
      ".config/containers"
      ".config/composer"
      ".config/git"
      ".config/btop"
      ".config/vial"
      ".local/share/easyeffects"
      ".local/share/opencode"
      ".local/share/nvim"
      ".local/share/nushell"
      ".local/share/containers"
      ".local/share/posting"
      ".local/share/keyrings"
      ".local/state/opencode"
      ".local/state/nvim"
      ".local/state/nix"
      ".local/state/wireplumber"
      ".local/state/lazygit"
      ".local/state/yazi"
    ];
    homeFiles = [
      ".cargo/credentials.toml"
    ];
  };
  projects = [
    "angst"
    "advent-of-code"
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
