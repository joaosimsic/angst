{ inputs, envPath, loadHost, ... }:

hostname:
let
  hostConfig = loadHost hostname;
in
inputs.nixpkgs.lib.nixosSystem {
  system = hostConfig.system;

  specialArgs = {
    inherit inputs hostname envPath;

    userConfig = hostConfig.user;
    
    monitors = hostConfig.monitors or {};
  };

  modules = [
    ../core
    ../hosts/${hostname}/configuration.nix
  ];
}
