{
  type = "nixos";
  system = "x86_64-linux";
  hostname = "vm";
  username = "joao";
  theme = "miasma";
  profiles = ["base" "desktop" "development" "vm"];
  toolchains = "*";
  repoPath = "proj/angst";

  monitors = {};

  db.connections = {};
  nixos = { keyboardLayout = "br-abnt2"; };
  home = {};
  env = { EDITOR = "nvim"; BROWSER = "firefox"; };
  shell = "";

  sshAgent = { enable = true; keys = ["~/.ssh/id_ed25519"]; };
  ssh = {};

  persist = { enable = false; };
}
