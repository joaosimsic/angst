{ lib, domainsPath }:

let
  scan = import ./scan.nix { inherit lib domainsPath; };
  xdg = import ./xdg.nix { inherit lib; };
  module = import ./module.nix {
    inherit lib;
    mkXdgSymlinks = xdg.mkXdgSymlinks;
  };
in
scan // module
