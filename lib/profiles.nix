{ profiles, lib, scan }:

let
  mkDomainEnable = import ./mkDomainEnable.nix { inherit lib scan; };

  profileMap = {
    base        = import ./profiles/base.nix        { inherit mkDomainEnable; };
    desktop     = import ./profiles/desktop.nix      { inherit mkDomainEnable; };
    development = import ./profiles/development.nix  { inherit mkDomainEnable; };
    server      = import ./profiles/server.nix       { inherit mkDomainEnable; };
    vm          = import ./profiles/vm.nix           { inherit mkDomainEnable; };
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
