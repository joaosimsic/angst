{ inputs, envPath, loadHost, ... }:

hostname: 
let
  hostConfig = loadHost hostname;
in
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = import inputs.nixpkgs {
    system = hostConfig.system;
    config.allowUnfree = true;
  };

  extraSpecialArgs = {
    inherit inputs envPath;
    userConfig = hostConfig.user;
  };

  modules = [ ../home.nix ];
}
