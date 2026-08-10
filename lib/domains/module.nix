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
      modulePath = "${path}/module.nix";
      hasCustomModule = builtins.pathExists modulePath;
      configSubdir = "${path}/config";
      hasConfigDir = builtins.pathExists configSubdir;
      hasRender = builtins.pathExists "${path}/render.nix";
      mutableBaseNames = meta.mutable or [ ];
      isCustomXdg = meta.customXdg or false;
      hasXdg = meta ? xdg;
      hasXdgFile = meta ? xdgFile;
      enableOption = config.domains.${category}.${name}.enable;

      configSourceEntries =
        if hasConfigDir && hasXdg && !isCustomXdg then
          let
            go =
              dirPath: prefix:
              lib.concatLists (
                lib.mapAttrsToList (
                  subName: subType:
                  let
                    fullPath = "${toString dirPath}/${subName}";
                    relPath = prefix + subName;
                    pathStr = toString fullPath;
                  in
                  if subType == "directory" then
                    go fullPath (relPath + "/")
                  else if subName == ".gitignore" then
                    [ ]
                  else if lib.hasInfix "/node_modules/" pathStr then
                    [ ]
                  else if lib.hasSuffix "/node_modules" pathStr then
                    [ ]
                  else if builtins.elem subName mutableBaseNames then
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
          in
          go configSubdir ""
        else
          [ ];

      xdgFileSourceEntries =
        if hasConfigDir && hasXdgFile && !isCustomXdg && !hasRender then
          let
            filePath = "${configSubdir}/${meta.xdgFile}";
          in
          [
            {
              target = meta.xdgFile;
              source = filePath;
            }
          ]
        else
          [ ];

      renderedFiles =
        if !hasRender then
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
              inherit
                lib
                themesLib
                checkHelpers
                monitors
                db
                sshAgent
                ;
              fontFamily = "JetBrainsMono Nerd Font";
              themeName = config.theme;
              homeDirectory = config.home.homeDirectory;
            };
            prefix = "domains/${category}/${name}/config/";
            entryForOutput =
              output:
              let
                relPath = lib.removePrefix prefix output.path;
              in
              lib.optional (hasXdg || (hasXdgFile && relPath == meta.xdgFile)) (
                lib.nameValuePair (
                  if hasXdg then ".config/${meta.xdg}/${relPath}" else ".config/${meta.xdgFile}"
                ) { inherit (output) text; }
              );
          in
          lib.listToAttrs (lib.concatMap entryForOutput outputs);

      renderedRelPaths =
        if hasRender && hasConfigDir && hasXdg && !isCustomXdg then
          let
            renderFn = import "${path}/render.nix";
            outputs = renderFn {
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
            prefix = "domains/${category}/${name}/config/";
          in
          lib.unique (
            lib.concatMap (o:
              let
                rel = lib.removePrefix prefix o.path;
              in
              lib.optional (lib.hasPrefix "domains/" o.path) rel
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
                e:
                let
                  relTarget = lib.removePrefix "${meta.xdg}/" e.target;
                in
                !(builtins.elem relTarget renderedRelPaths)
              ) allEntries;
            in
            builtins.listToAttrs (
              map (e: lib.nameValuePair e.target { inherit (e) source; }) filteredEntries
            );
        };
      };

      renderOverrideModule = {
        config = lib.mkIf enableOption {
          home.file =
            let
              files =
                if hasRender && hasConfigDir && hasXdg && !isCustomXdg then renderedFiles
                else { };
              filteredFiles = lib.filterAttrs (key: _: !(builtins.elem (baseNameOf key) mutableBaseNames)) files;
            in
            filteredFiles;
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
