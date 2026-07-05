{ inputs, loadHost, flakeSelf, vmTool, ... }:

let
  mkHomeProfile = hostname:
    let
      hostConfig = loadHost hostname;

      system = hostConfig.system;

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
        inherit inputs flakeSelf themesLib hostTheme;
        userConfig = hostConfig.user;
        monitors = hostConfig.monitors or {};
      };

      modules = [
        ../../lib/home
        (import ../home/themeModule.nix { inherit lib themesLib hostTheme; })
        ../home/i3Fragments.nix
        ../../hosts/${hostname}/home.nix

        ({ pkgs, ...}: {
          home.packages = [ vmTool ];
        })
        ({ ... }: {
          home.file.".ssh/config".force = true;
        })
      ] ++ homeModules;
    };
in
rec {
  inherit mkHomeProfile;

  mkHomeWithExtraModules = hostname: extraModules:
    let
      profile = mkHomeProfile hostname;
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit (profile) pkgs extraSpecialArgs;
      modules = profile.modules ++ extraModules;
    };

  mkHome = hostname: mkHomeWithExtraModules hostname [ ];
}
