{ lib, scan }:

name:
let
  entries = scan.domains.homeEntries ++ scan.domains.nixosEntries;
  domain = lib.findFirst (e: "${e.category}.${e.name}" == name) null entries;
in
if domain == null then
  builtins.throw "Unknown domain '${name}'. Available: ${builtins.concatStringsSep ", " (map (e: "${e.category}.${e.name}") entries)}"
else {
  domains.${domain.category}.${domain.name}.enable = true;
}
