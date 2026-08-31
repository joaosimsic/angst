{
  type = "home";
  system = "x86_64-linux";
  hostname = "mint";
  username = "joao";
  theme = "miasma";
  profiles = [
    "base"
    "desktop"
    "development"
    "embedded"
    "vm"
  ];
  toolchains = "*";
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
  # ftp = {
  #   mounts = [
  #     {
  #       mountPoint = "ftp/server";
  #       remotePath = "/httpdocs";
  #
  #     }
  #   ];
  # };
  projects = [
    "angst"
    "advent-of-code"
    "datapath"
    "agent"
    "intelligence/backend"
    "intelligence/frontend"
  ];
  secrets = [
    "opencode-go-key"
    "cursor-api-key"
  ];
}
