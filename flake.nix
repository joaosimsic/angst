{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
  let
    hosts = import ./lib/scanHosts.nix inputs;

    env = {
      inherit inputs;

      envPath = "/home/joao/.config/angst";
      loadHost = hostname: import (./hosts + "/${hostname}");
    };

    mkHost = import ./lib/mkHost.nix env;
    mkHome = import ./lib/mkHome.nix env;
  in
  {
    nixosConfigurations = nixpkgs.lib.genAttrs hosts mkHost; 

    homeConfigurations = 
      let
        perHost = nixpkgs.lib.genAttrs
          (map (h: "joao@${h}") hosts) 
          (name: mkHome (nixpkgs.lib.removePrefix "joao@" name));
      in
        perHost // { "joao" = mkHome "personal"; };
  };
}
