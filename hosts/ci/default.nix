{
  type = "nixos";
  system = "x86_64-linux";
  hostname = "ci";
  username = "runner";
  theme = "monochrome";
  profiles = [ "base" ];
  toolchains = [ "nix" ];
  repoPath = "proj/angst";
}
