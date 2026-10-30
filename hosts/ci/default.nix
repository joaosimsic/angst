{
  type = "nixos";
  system = "x86_64-linux";
  hostname = "ci";
  username = "runner";
  theme = "miasma";
  profiles = [ "ci" ];
  toolchains = [ "nix" ];
}
