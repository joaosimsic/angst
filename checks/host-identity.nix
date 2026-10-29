{
  self,
  lib,
  pkgs,
}:

let
  discover = import ../lib/discover.nix { inherit lib; };
  entries = discover (self + "/hosts");

  declared =
    entry:
    let
      decl = import (self + "/hosts/${entry.dir}");
    in
    {
      inherit (entry) dir;
      hostname = decl.hostname or "nixos";
    };

  hosts = map declared entries;
  names = map (h: h.hostname) hosts;
  duplicates = builtins.filter (n: builtins.length (builtins.filter (x: x == n) names) > 1) (
    lib.unique names
  );
in
if duplicates != [ ] then
  throw "Host identity check failed: duplicate hostname(s): ${builtins.concatStringsSep ", " duplicates}"
else
  pkgs.runCommand "check-host-identity" { } ''
    echo "PASS: ${toString (builtins.length hosts)} host declaration(s) use unique hostnames"
    touch $out
  ''
