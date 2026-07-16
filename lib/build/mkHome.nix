{
  inputs,
  loadHost,
  flakeSelf,
  vmTool,
  shellTool,
  angstTool,
  ...
}:

let
  mkHomeProfile =
    hostname:
    let
      hostConfig = loadHost hostname;

      parseEnv = import ../parseEnv.nix { inherit (inputs.nixpkgs) lib; };
      envPath = ../../user.env;
      pwd = builtins.getEnv "PWD";
      pwdEnvPath = if pwd != "" then pwd + "/user.env" else "";
      homeEnvPath = builtins.getEnv "HOME" + "/proj/angst/user.env";
      userEnv = let
        fromFile = if builtins.pathExists envPath then parseEnv envPath
          else if builtins.pathExists homeEnvPath then parseEnv homeEnvPath
          else if pwdEnvPath != "" && builtins.pathExists pwdEnvPath then parseEnv pwdEnvPath
          else { };
      in fromFile // (
        let u = builtins.getEnv "ANGST_USERNAME"; h = builtins.getEnv "ANGST_HOST"; in
        (if h != "" then { HOST = h; } else {}) // (if u != "" then { USERNAME = u; } else {})
      );

      pkgs = import inputs.nixpkgs {
        inherit (hostConfig) system;
        config.allowUnfree = true;
      };

      inherit (pkgs) lib;

      effectiveUsername = let
        envUser = builtins.getEnv "ANGST_USERNAME";
      in
        if envUser != "" then envUser
        else userEnv.USERNAME or hostConfig.user.username;
      effectiveUserConfig = hostConfig.user // {
        username = effectiveUsername;
        homeDirectory = "/home/${effectiveUsername}";
      };

      themesLib = import ../../themes/default.nix { inherit lib; };
      hostTheme = let
        envTheme = builtins.getEnv "ANGST_THEME";
      in
        if envTheme != "" then envTheme
        else userEnv.THEME or hostConfig.theme or themesLib.default;

      domainsPath = ../../domains;
      domainsLib = import ../domains/default.nix { inherit lib domainsPath; };

      homeModules = map domainsLib.mkDomainModule domainsLib.homeEntries;
    in
    {
      inherit pkgs;

      extraSpecialArgs = {
        inherit
          inputs
          flakeSelf
          themesLib
          hostTheme
          userEnv
          ;
        userConfig = effectiveUserConfig;
        monitors = hostConfig.monitors or { };
        repoPath = hostConfig.repoPath or "proj/angst";
        hostName = hostname;
      };

      modules = [
        ../../lib/home
        (import ../home/themeModule.nix { inherit lib themesLib hostTheme; })
        ../home/i3Fragments.nix
        ../../hosts/${hostname}/home.nix

        (_: {
          home.packages =
            lib.optionals (hostConfig.enableVmTool or true) [ vmTool ]
            ++ lib.optionals (hostConfig.enableShellTool or true) [ shellTool ]
            ++ lib.optionals (hostConfig.enableAngstTool or true) [ angstTool ];
        })

      ]
      ++ homeModules;
    };
in
rec {
  inherit mkHomeProfile;

  mkHomeWithExtraModules =
    hostname: extraModules:
    let
      profile = mkHomeProfile hostname;
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit (profile) pkgs extraSpecialArgs;
      modules = profile.modules ++ extraModules;
    };

  mkHome = hostname: mkHomeWithExtraModules hostname [ ];
}
