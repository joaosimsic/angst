{ nixpkgs, ... }:

let
  hostsPath = ../../hosts;
  hostsContent = builtins.readDir hostsPath;
in
builtins.attrNames (nixpkgs.lib.attrsets.filterAttrs (_: type: type == "directory") hostsContent)
