{ inputs, envPath, loadHost, ... }:

hostname: 
let
  hostConfig = loadHost hostname;

  domains = import ../domains { };
in
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = import inputs.nixpkgs {
    system = hostConfig.system;
    config.allowUnfree = true;
  };

  extraSpecialArgs = {
    inherit inputs envPath domains;

    userConfig = hostConfig.user;

    monitors = hostConfig.monitors or {};
  };

  modules = [ ../core/home.nix ];
}
