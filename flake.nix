{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    vm = {
      url = "./tools/vm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    shell = {
      url = "./tools/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      themesLib = import ./themes/default.nix { inherit lib; };
      resolve = import ./lib/resolve.nix;

      hostsDir = ./hosts;

      hostEntries =
        let
          topEntries = builtins.readDir hostsDir;

          processTopEntry = name: type:
            if type != "directory" then [ ] else
            let
              subDir = hostsDir + "/${name}";
              subEntries = builtins.readDir subDir;
            in
            if subEntries ? "default.nix" && subEntries."default.nix" == "regular" then
              [{ hostname = name; domain = null; dir = name; }]
            else
              lib.mapAttrsToList (hostName: hostType:
                if hostType == "directory" then
                  let
                    hostDir = subDir + "/${hostName}";
                    hostEntries' = builtins.readDir hostDir;
                  in
                  if hostEntries' ? "default.nix" && hostEntries'."default.nix" == "regular" then
                    { hostname = hostName; domain = name; dir = "${name}/${hostName}"; }
                  else null
                else null
              ) subEntries;
        in
        lib.filter (x: x != null) (lib.flatten (lib.mapAttrsToList processTopEntry topEntries));

      mkCfg = { domain, dir, ... }:
        let
          rawConfig = import (hostsDir + "/${dir}");
        in
        (resolve { inherit inputs themesLib domain; config = rawConfig; }).cfg;

      hostCfgs = builtins.listToAttrs (map (h: { name = h.hostname; value = mkCfg h; }) hostEntries);
    in
    import ./lib/flake/outputs.nix {
      inherit
        self
        inputs
        hostCfgs
        themesLib
        ;
    };
}
