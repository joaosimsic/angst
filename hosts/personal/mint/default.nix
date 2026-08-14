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
  ssh = { };
  ftp = {
    mounts = [
      {
        mountPoint = "ftp/server";
      }
    ];
  };
  projects = [ "7391b51c36a7d266" ];
}
