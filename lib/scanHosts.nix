{ nixpkgs, ... }:

let
  hostsPath = ../hosts;
  hostsContent = builtins.readDir hostsPath;
in
builtins.attrNames (
  nixpkgs.lib.attrsets.filterAttrs
    (name: type: type == "directory")
    hostsContent
)
