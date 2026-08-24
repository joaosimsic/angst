{
  type = "home";
  system = "x86_64-linux";
  hostname = "home";
  username = "joao";
  theme = "miasma";
  profiles = [
    "base"
    "development"
  ];
  toolchains = "*";
  env = {
    EDITOR = "nvim";
  };
  shell = "";
  sshAgent = {
    enable = true;
    keys = [ "~/.ssh/work_ed25519" ];
  };
  ssh = {
    hosts = [
      {
        host = "gitlab.com";
        hostName = "gitlab.com";
        user = "git";
        identityFile = "~/.ssh/work_ed25519";
      }
      {
        host = "work_server";
        hostName = "200.152.183.154";
        user = "joao";
        identityFile = "~/.ssh/work_ed25519";
      }
    ];
  };
  secrets = [
    "cursor-api-key"
    "opencode-go-key"
  ];
}
