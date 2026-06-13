{ lib, mkDomainActivation }:

let
  mkTokens = import ../template/tokens.nix;

  mkDomainModule = entry: { config, lib, pkgs, themesLib, renderTemplate, ... }:
  let
    inherit (entry) category name meta path;
    modulePath = "${path}/module.nix";
    hasCustomModule = builtins.pathExists modulePath;
    configSubdir = "${path}/config";
    configDir =
      if builtins.pathExists configSubdir then
        configSubdir
      else
        path;

    baseModule = {
      options.domains.${category}.${name} = {
        enable = lib.mkEnableOption "Enable ${meta.description or name}";
      };

      config = lib.mkIf config.domains.${category}.${name}.enable (
        {
          home.packages = lib.optionals (meta ? package) [
            pkgs.${meta.package}
          ];
        }
        // lib.optionalAttrs (!(meta.customXdg or false)) (
          mkDomainActivation {
            inherit configDir meta category name;
            tokens = mkTokens {
              inherit lib themesLib;
              theme = config.theme;
              fontFamily = config.font.family;
            };
            inherit (config.home) homeDirectory;
            inherit lib pkgs renderTemplate;
          }
        )
      );
    };

    customModule = if hasCustomModule then import modulePath else { };
  in
  {
    imports = [ baseModule customModule ];
  };

  mkNixosDomainModule = entry:
  let
    nixosPath = "${entry.path}/nixos.nix";
  in
    if builtins.pathExists nixosPath then
      import nixosPath
    else
      { };
in
{
  inherit mkDomainModule mkNixosDomainModule;
}
