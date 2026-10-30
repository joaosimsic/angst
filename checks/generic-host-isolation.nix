{
  self,
  lib,
  pkgs,
}:

let
  names = builtins.attrNames self.nixosConfigurations;
  enabled = lib.filter (
    name: self.nixosConfigurations.${name}.config.angst.genericHost.enable or false
  ) names;
in
if enabled != [ "generic" ] then
  throw "generic-host-isolation: expected only [\"generic\"] to enable angst.genericHost, got ${builtins.toJSON enabled}"
else
  pkgs.runCommand "generic-host-isolation" { } ''
    mkdir -p "$out"
    printf '%s\n' "only generic enables angst.genericHost" >"$out/README"
  ''
