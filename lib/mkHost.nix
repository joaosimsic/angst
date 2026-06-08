{ inputs, loadHost, mkHomeProfile, ... }:

hostname:
let
  hostConfig = loadHost hostname;
  capabilities = import ../capabilities { };
  profile = mkHomeProfile hostname;
in
inputs.nixpkgs.lib.nixosSystem {
  system = hostConfig.system;

  specialArgs = {
    inherit inputs hostname capabilities;

    userConfig = hostConfig.user;

    monitors = hostConfig.monitors or {};
  };

  modules = [
    ../core
    ../hosts/${hostname}/configuration.nix
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "hm-backup";
      home-manager.extraSpecialArgs = profile.extraSpecialArgs;
      home-manager.users.${hostConfig.user.username} = {
        imports = profile.modules;
      };

      # Ensure domain configs are linked before login shells can start nushell.
      systemd.services."home-manager-${hostConfig.user.username}".before = [
        "getty@.service"
        "serial-getty@.service"
      ];
    }
  ] ++ builtins.attrValues capabilities;
}
