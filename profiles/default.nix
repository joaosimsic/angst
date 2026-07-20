{ profiles, lib, scan }:

let
  mkDomainEnable = name:
    let
      entries = scan.domains.homeEntries ++ scan.domains.nixosEntries;
      domain = lib.findFirst (e: "${e.category}.${e.name}" == name) null entries;
    in
    if domain == null then
      builtins.throw "Unknown domain '${name}'. Available: ${builtins.concatStringsSep ", " (map (e: "${e.category}.${e.name}") entries)}"
    else {
      domains.${domain.category}.${domain.name}.enable = true;
    };

  profileMap = {
    base        = import ./base.nix        { inherit mkDomainEnable; };
    desktop     = import ./desktop.nix      { inherit mkDomainEnable; };
    development = import ./development.nix  { inherit mkDomainEnable; };
    server      = import ./server.nix       { inherit mkDomainEnable; };
    vm          = import ./vm.nix           { inherit mkDomainEnable; };
  };

  resolve = names:
    let
      validNames = builtins.attrNames profileMap;
      unknown = builtins.filter (n: !builtins.elem n validNames) names;
    in
    if unknown != []
    then builtins.throw "Unknown profiles: ${builtins.concatStringsSep ", " unknown}. Valid: ${builtins.concatStringsSep ", " validNames}"
    else {
      hm    = lib.concatMap (n: profileMap.${n}.hm)  names;
      nixos = lib.concatMap (n: profileMap.${n}.nixos) names;
    };
in
resolve profiles
