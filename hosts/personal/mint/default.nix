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
    keys = [ "~/.ssh/id_ed25519" ];
  };
  ssh = { };
  projects = [ ]; # opaque store ids (angst projects status); names stay encrypted
}
