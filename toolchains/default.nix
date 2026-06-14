{ lib, ... }:

let
  toolchainsPath = ./.;
  entries = builtins.readDir toolchainsPath;
  
  toolchainFiles = lib.filterAttrs
    (name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix")
    entries;
  
  imports = map (name: ./${name}) (builtins.attrNames toolchainFiles);
in
{
  inherit imports;
}
