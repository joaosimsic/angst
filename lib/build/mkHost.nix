{
  inputs,
  loadHost,
  mkHomeProfile,
  flakeSelf,
  ...
}:

hostname:
let
  hostConfig = loadHost hostname;

  parseEnv = import ../parseEnv.nix { lib = inputs.nixpkgs.lib; };
  envPath = ../../user.env;
  userEnv = if builtins.pathExists envPath then parseEnv envPath else { };

  effectiveUsername = let
    envUser = builtins.getEnv "ANGST_USERNAME";
  in
    if envUser != "" then envUser
    else hostConfig.user.username;
  effectiveUserConfig = hostConfig.user // {
    username = effectiveUsername;
    homeDirectory = "/home/${effectiveUsername}";
  };
  effectiveTheme = let
    envTheme = builtins.getEnv "ANGST_THEME";
  in
    if envTheme != "" then envTheme
    else userEnv.THEME or hostConfig.theme or "monochrome";

  capabilities = import ../../capabilities { };
  profile = mkHomeProfile hostname;

  domainsLib = import ../domains/default.nix {
    inherit (inputs.nixpkgs) lib;
    domainsPath = ../../domains;
  };
  domainNixosModules = map domainsLib.mkNixosDomainModule domainsLib.nixosEntries;
in
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = {
    inherit
      inputs
      hostname
      capabilities
      flakeSelf
      userEnv
      ;

    userConfig = effectiveUserConfig;

    monitors = hostConfig.monitors or { };

    theme = effectiveTheme;

    repoPath = hostConfig.repoPath or "proj/angst";
  };

  modules = [
    { nixpkgs.hostPlatform = hostConfig.system; }
    ../../lib/nixos
    ../../hosts/${hostname}/configuration.nix
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "hm-backup";
        inherit (profile) extraSpecialArgs;
        users.${effectiveUsername} = {
          imports = profile.modules;
        };
      };
    }

    
    
    ({ config, lib, ... }: {
      systemd.services."home-manager-${effectiveUsername}".before = lib.mkIf (!config.angst.isQemuVm) [
        "getty@.service"
        "serial-getty@.service"
      ];
    })
  ]
  ++ builtins.attrValues capabilities
  ++ domainNixosModules;
}
