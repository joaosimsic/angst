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
    "design"
    "game-dev"
    "office"
    "remote"
  ];
  toolchains = [
    "javascript"
    "php"
    "python"
    "bash"
    "json"
    "nix"
    "go"
    "lua"
    "yaml"
    "docker"
    "toml"
    "conf"
    "make"
    "rust"
    "just"
    "markdown"
    "html"
    "css"
    "c"
    "xml"
    "editorconfig"
    "blade"
    "scm"
  ];
  db = [ "work/intelligence-metadata" ];
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
  projects = [
    "angst"
    "advent-of-code"
    "boring"
    "datapath"
    "llm-ruler"
    "agent"
    "threefold"
    "stealing-eye"
    "Throughput"
    "Throughput-Releases"
    "vault"
    "TCC"
    "Tyto"
    "box"
    "intelligence/backend"
    "intelligence/frontend"
  ];
  secrets = {
    scopes = [
      "personal"
      "work"
    ];
    apps = [
      "personal/opencode-go-key"
      "work/cursor-api-key"
    ];
    host = [ "personal/tailscale" ];
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
  home =
    { lib, ... }:
    {
      domains.notifications.enable = lib.mkForce false;
    };
}
