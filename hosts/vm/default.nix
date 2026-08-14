{
  type = "nixos";
  system = "x86_64-linux";
  hostname = "vm";
  username = "joao";
  theme = "miasma";
  profiles = [
    "base"
    "desktop"
    "development"
    "vm"
  ];
  toolchains = "*";

  monitors = { };

  db.connections = { };
  nixos = {
    keyboardLayout = "br-abnt2";
    # ftp mounts are work-scoped secrets; the VM needs the work age key to decrypt them
    angst.vm.injectWorkAgeKey = true;
  };
  home = { };
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
  ftp = {
    mounts = [
      {
        mountPoint = "ftp/server";
      }
    ];
  };

  persist = {
    enable = true;
    root = "/persist";
    homeDirs = [
      ".ssh"
      ".local/share"
      ".config"
      ".cache"
    ];
  };
  projects = [
    "7391b51c36a7d266"
  ]; # opaque store ids (angst projects status); names stay encrypted
}
