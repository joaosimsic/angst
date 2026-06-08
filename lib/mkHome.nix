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
      theme = themesLib.get (hostConfig.theme or themesLib.default);

      domainsPath = ../domains;
      domainsLib = import ./domains.nix { inherit lib domainsPath; };

      homeModules = map domainsLib.mkDomainModule domainsLib.homeEntries;
    in
    {
      inherit pkgs;

      extraSpecialArgs = {
        inherit inputs theme;

        userConfig = hostConfig.user;

        monitors = hostConfig.monitors or {};
      };

      modules = [
        ../core/home.nix
        ../hosts/${hostname}/home.nix
      ] ++ homeModules;
    };
in
{
  inherit mkHomeProfile;

  mkHome = hostname:
    let
      profile = mkHomeProfile hostname;
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit (profile) pkgs extraSpecialArgs modules;
    };
}
