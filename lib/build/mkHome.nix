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

      pkgs = import inputs.nixpkgs {
        system = hostConfig.system;
        config.allowUnfree = true;
      };

      inherit (pkgs) lib;

      themesLib = import ../../themes/default.nix { inherit lib; };
      hostTheme = hostConfig.theme or themesLib.default;

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
          ;
        userConfig = hostConfig.user;
        monitors = hostConfig.monitors or { };
        repoPath = hostConfig.repoPath or "proj/angst";
      };

      modules = [
        ../../lib/home
        (import ../home/themeModule.nix { inherit lib themesLib hostTheme; })
        ../home/i3Fragments.nix
        ../../hosts/${hostname}/home.nix

        ({ ... }: {
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
