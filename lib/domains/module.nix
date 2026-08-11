_:

let
  mkDomainModule =
    entry:
    {
      config,
      lib,
      pkgs,
      themesLib,
      monitors,
      db,
      sshAgent ? { },
      ...
    }:
    let
      inherit (entry)
        category
        name
        meta
        path
        ;
      modulePath = "${path}/home.nix";
      hasCustomModule = builtins.pathExists modulePath;
      configSubdir = "${path}/config";
      hasConfigDir = builtins.pathExists configSubdir;
      hasRender = builtins.pathExists "${path}/render.nix";
      mutableBaseNames = meta.mutable or [ ];
      isCustomXdg = meta.customXdg or false;
      hasXdg = meta ? xdg;
      hasXdgFile = meta ? xdgFile;
      enableOption = config.domains.${category}.${name}.enable;

      outputs =
        if !hasRender then
          [ ]
        else
          (import "${path}/render.nix") {
            inherit
              lib
              themesLib
              monitors
              db
              sshAgent
              ;
            checkHelpers = import ../../checks/theme/assertions.nix {
              inherit lib;
              themeName = config.theme;
              theme = themesLib.get config.theme;
            };
            fontFamily = "JetBrainsMono Nerd Font";
            themeName = config.theme;
            homeDirectory = config.home.homeDirectory;
          };

      isSkippable =
        subName: pathStr:
        subName == ".gitignore"
        || lib.hasInfix "/node_modules/" pathStr
        || lib.hasSuffix "/node_modules" pathStr
        || builtins.elem subName mutableBaseNames;

      go =
        dirPath: prefix:
        lib.concatLists (
          lib.mapAttrsToList (
            subName: subType:
            let
              fullPath = "${toString dirPath}/${subName}";
              relPath = prefix + subName;
            in
            if subType == "directory" then
              go fullPath (relPath + "/")
            else if isSkippable subName (toString fullPath) then
              [ ]
            else
              [
                {
                  target = "${meta.xdg}/${relPath}";
                  source = fullPath;
                }
              ]
          ) (builtins.readDir dirPath)
        );

      configSourceEntries = if hasConfigDir && hasXdg && !isCustomXdg then go configSubdir "" else [ ];

      xdgFileSourceEntries =
        if hasConfigDir && hasXdgFile && !isCustomXdg && !hasRender then
          [
            {
              target = meta.xdgFile;
              source = "${configSubdir}/${meta.xdgFile}";
            }
          ]
        else
          [ ];

      prefix = "domains/${category}/${name}/config/";

      renderedFiles = lib.listToAttrs (
        lib.concatMap (
          output:
          let
            relPath = lib.removePrefix prefix output.path;
          in
          lib.optional (hasXdg || (hasXdgFile && relPath == meta.xdgFile)) (
            lib.nameValuePair (if hasXdg then ".config/${meta.xdg}/${relPath}" else ".config/${meta.xdgFile}") {
              inherit (output) text;
            }
          )
        ) outputs
      );

      renderedRelPaths =
        if hasRender && hasConfigDir && hasXdg && !isCustomXdg then
          lib.unique (
            lib.concatMap (
              o: lib.optional (lib.hasPrefix "domains/" o.path) (lib.removePrefix prefix o.path)
            ) outputs
          )
        else
          [ ];

      baseModule = {
        options.domains.${category}.${name} = {
          enable = lib.mkEnableOption "Enable ${meta.description or name}";
        };

        config = lib.mkIf enableOption {
          home.packages = lib.optionals (meta ? package) [
            pkgs.${meta.package}
          ];
          home.file = lib.mkIf (hasRender && (!hasConfigDir || hasXdgFile || isCustomXdg)) renderedFiles;
        };
      };

      customModule = if hasCustomModule then import modulePath else { };

      configSourceModule = {
        config = lib.mkIf enableOption {
          xdg.configFile =
            let
              allEntries = configSourceEntries ++ xdgFileSourceEntries;
              filteredEntries = lib.filter (
                e: !(builtins.elem (lib.removePrefix "${meta.xdg}/" e.target) renderedRelPaths)
              ) allEntries;
            in
            builtins.listToAttrs (map (e: lib.nameValuePair e.target { inherit (e) source; }) filteredEntries);
        };
      };

      renderOverrideModule = {
        config = lib.mkIf enableOption {
          home.file =
            let
              files = if hasRender && hasConfigDir && hasXdg && !isCustomXdg then renderedFiles else { };
            in
            lib.filterAttrs (key: _: !(builtins.elem (baseNameOf key) mutableBaseNames)) files;
        };
      };
    in
    {
      imports = [
        baseModule
        configSourceModule
        renderOverrideModule
        customModule
      ];
    };

  mkNixosSystemModule =
    entry:
    let
      systemPath = "${entry.path}/system.nix";
    in
    if builtins.pathExists systemPath then import systemPath else { };
in
{
  inherit mkDomainModule mkNixosSystemModule;
}
