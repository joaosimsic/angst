{ inputs, loadHost, ... }:

let
  mkHomeProfile = hostname:
    let
      hostConfig = loadHost hostname;

      pkgs = import inputs.nixpkgs {
        system = hostConfig.system;
        config.allowUnfree = true;
      };

      inherit (pkgs) lib;

      themesLib = import ../themes/default.nix { inherit lib; };
      hostTheme = hostConfig.theme or themesLib.default;

      domainsPath = ../domains;
      domainsLib = import ./domains.nix { inherit lib domainsPath; };
      renderTemplate = import ./renderTemplate.nix;

      homeModules = map domainsLib.mkDomainModule domainsLib.homeEntries;
    in
    {
      inherit pkgs;

      extraSpecialArgs = {
        inherit inputs themesLib hostTheme renderTemplate;

        userConfig = hostConfig.user;

        monitors = hostConfig.monitors or {};
      };

      modules = [
        ../core/home.nix
        (import ../lib/themeModule.nix { inherit lib themesLib hostTheme; })
        ../lib/i3Fragments.nix
        ../hosts/${hostname}/home.nix
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
