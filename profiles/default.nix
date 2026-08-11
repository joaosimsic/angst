{
  profiles,
  lib,
  scan,
}:

let
  entries = scan.domains.entries;

  entryFor =
    name:
    let
      entry = lib.findFirst (e: "${e.category}.${e.name}" == name) null entries;
    in
    if entry == null then
      throw "Unknown domain '${name}'. Available: ${
        builtins.concatStringsSep ", " (map (e: "${e.category}.${e.name}") entries)
      }"
    else
      entry;

  profileMap = {
    base = import ./base.nix;
    desktop = import ./desktop.nix;
    development = import ./development.nix;
    server = import ./server.nix;
    vm = import ./vm.nix;
  };

  resolve =
    names:
    let
      validNames = builtins.attrNames profileMap;
      unknown = builtins.filter (n: !builtins.elem n validNames) names;
    in
    if unknown != [ ] then
      throw "Unknown profiles: ${builtins.concatStringsSep ", " unknown}. Valid: ${builtins.concatStringsSep ", " validNames}"
    else
      {
        enabled = map entryFor (lib.concatMap (n: profileMap.${n}.enable or [ ]) names);
        modules = lib.concatMap (n: profileMap.${n}.modules or [ ]) names;
      };
in
resolve profiles
