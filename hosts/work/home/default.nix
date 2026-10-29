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
  toolchains = [
    "javascript"
    "php"
    "python"
    "json"
    "bash"
    "nix"
    "go"
    "lua"
    "yaml"
    "docker"
    "toml"
    "conf"
    "make"
    "just"
    "markdown"
    "html"
    "css"
    "c"
    "xml"
    "editorconfig"
    "blade"
  ];
  db = [ ];
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
        host = "gitlab.ezvoice.com.br";
        hostName = "gitlab.ezvoice.com.br";
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
  projects = [
    "agent"
    "box"
    "intelligence/backend"
    "intelligence/frontend"
  ];
  secrets = {
    scopes = [ "work" ];
    apps = [ "work/cursor-api-key" ];
  };
  git = {
    default = "work";
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
