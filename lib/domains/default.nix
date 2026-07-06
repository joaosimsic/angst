{ lib, domainsPath }:

let
  scan = import ./scan.nix { inherit lib domainsPath; };
  activation = import ./activation.nix { inherit lib; };
  module = import ./module.nix {
    inherit lib;
    inherit (activation) mkDomainActivation;
  };
in
scan // module
