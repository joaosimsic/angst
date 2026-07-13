{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
    {
      self,
      nixpkgs,
      vm,
      shell,
      ...
    }@inputs:
    let
      hosts = import ./lib/build/scanHosts.nix inputs;

      env = {
        inherit inputs;

        flakeSelf = self;

        loadHost = hostname: import (./hosts + "/${hostname}");
      };

      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      vmOutputs = vm.mkOutputs self;
      shellOutputs = shell.mkOutputs self;

      domainsLib = import ./lib/domains/default.nix {
        lib = pkgs.lib;
        domainsPath = ./domains;
      };
      shellEntries = builtins.filter (e: e.category == "shell") domainsLib.homeEntries;
      commonHomeEnables = import ./common/home.nix { };
      enabledShellEntries = builtins.filter (e:
        (e.meta.interactive or false)
        && pkgs.lib.attrByPath [ "domains" "shell" e.name "enable" ] false commonHomeEnables
      ) shellEntries;
      hostShellBinPaths = pkgs.lib.concatStringsSep ":" (
        map (e: "${pkgs.${e.meta.package}}/bin/${e.meta.binary}") enabledShellEntries
      );

      shared = import ./lib/flake/shared.nix {
        inherit pkgs shellOutputs vmOutputs system hostShellBinPaths;
        lib = pkgs.lib;
        defaultHost = builtins.head hosts;
      };

      homeLib = import ./lib/build/mkHome.nix (
        env
        // {
          vmTool = vmOutputs.packages.${system}.default;
          shellTool = shared.shellTool;
          angstTool = shared.angstCli;
        }
      );

      mkHost = import ./lib/build/mkHost.nix (
        env
        // {
          inherit (homeLib) mkHomeProfile;
          flakeSelf = self;
        }
      );

      inherit (homeLib) mkHome mkHomeWithExtraModules;

      flakeLib = import ./lib/flake/default.nix {
        inherit
          self
          system
          pkgs
          hosts
          mkHome
          mkHomeWithExtraModules
          hostShellBinPaths
          ;
        inherit vmOutputs shellOutputs;
        inherit (env) loadHost;
        inherit (pkgs) lib;
      };
    in
    {
      nixosConfigurations = let
        parseEnv = import ./lib/parseEnv.nix { lib = nixpkgs.lib; };
        envPath = ./user.env;
        userEnv = (if builtins.pathExists envPath then parseEnv envPath else { }) // (
          let h = builtins.getEnv "ANGST_HOST"; in if h != "" then { HOST = h; } else {}
        );
        configs = nixpkgs.lib.genAttrs
          (builtins.filter (h: builtins.pathExists (./hosts + "/${h}/configuration.nix")) hosts)
          mkHost;
      in
      configs // {
        default = let
          hostname = userEnv.HOST or (builtins.head hosts);
        in
        if configs ? ${hostname} then configs.${hostname}
        else builtins.throw "HOST '${hostname}' not found. Available: ${builtins.toString (builtins.attrNames configs)}";
      };

      inherit (flakeLib)
        homeConfigurations
        checks
        packages
        apps
        devShells
        ;

      formatter.${system} = pkgs.nixfmt;

      lib = {
        inherit (flakeLib)
          themeLint
          renderDomainOutputsFor
          renderDomainOutputPathsFor
          renderDomainOutputFor
          ;
      };
    };
}
