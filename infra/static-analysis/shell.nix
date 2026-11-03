let
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);

  nixpkgs = fetchTree {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    inherit (lock.nodes.nixpkgs.locked) rev narHash;
  };

  pkgs = import nixpkgs { };
in
pkgs.mkShell {
  packages = with pkgs; [
    statix
    deadnix
    nixfmt
    yamllint
    golangci-lint
  ];
}
