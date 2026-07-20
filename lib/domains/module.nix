{ mkDomainActivation }:

let
  mkDomainModule =
    entry:
    {
      config,
      lib,
      pkgs,
      themesLib,
      repoPath,
      monitors,
      ...
    }:
    let
      inherit (entry)
        category
        name
        meta
        path
        ;
      modulePath = "${path}/module.nix";
      hasCustomModule = builtins.pathExists modulePath;
      configSubdir = "${path}/config";
      hasConfigDir = builtins.pathExists configSubdir;
      hasRender = builtins.pathExists "${path}/render.nix";

      renderedHomeFiles =
        if !hasRender then
          { }
        else if hasConfigDir && !(meta ? xdgFile) then
          { }
        else
          let
            render = import "${path}/render.nix";
            checkHelpers = import ../../checks/theme/assertions.nix {
              inherit lib;
              themeName = config.theme;
              theme = themesLib.get config.theme;
            };
            outputs = render {
              inherit lib themesLib checkHelpers monitors;
              themeName = config.theme;
              homeDirectory = config.home.homeDirectory;
            };
            prefix = "domains/${category}/${name}/config/";
            entryForOutput =
              output:
              let
                relPath = lib.removePrefix prefix output.path;
              in
              lib.optional (meta ? xdg || (meta ? xdgFile && relPath == meta.xdgFile)) (
                lib.nameValuePair (
                  if meta ? xdg then ".config/${meta.xdg}/${relPath}" else ".config/${meta.xdgFile}"
                ) { inherit (output) text; }
              );
          in
          lib.listToAttrs (lib.concatMap entryForOutput outputs);

      baseModule = {
        options.domains.${category}.${name} = {
          enable = lib.mkEnableOption "Enable ${meta.description or name}";
        };

        config = lib.mkIf config.domains.${category}.${name}.enable {
          home.packages = lib.optionals (meta ? package) [
            pkgs.${meta.package}
          ];
          home.file = renderedHomeFiles;
        };
      };

      customModule = if hasCustomModule then import modulePath else { };

      activationModule =
        if hasConfigDir && !(hasRender && meta ? xdgFile) then
          {
            config = lib.mkIf config.domains.${category}.${name}.enable (mkDomainActivation {
              configDir = configSubdir;
              inherit meta category name;
              inherit (config.home) homeDirectory;
              inherit lib repoPath;
            });
          }
        else
          { };
    in
    {
      imports = [
        baseModule
        activationModule
        customModule
      ];
    };

  mkNixosDomainModule =
    entry:
    let
      nixosPath = "${entry.path}/nixos.nix";
    in
    if builtins.pathExists nixosPath then import nixosPath else { };
in
{
  inherit mkDomainModule mkNixosDomainModule;
}
