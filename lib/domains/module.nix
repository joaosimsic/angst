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
        home
        hasRender
        render
        hasConfigDir
        ;
      configDir = entry.config;
      mutableBaseNames = meta.mutable or [ ];
      isCustomXdg = meta.customXdg or false;
      hasXdg = meta.xdg != null;
      hasXdgFile = meta.xdgFile != null;
      enableOption = config.domains.${category}.${name}.enable;

      prefix = "domains/${category}/${name}/config/";

      validateOutputs = outs:
        let
          check = o:
            if !(builtins.isAttrs o)
            || !(builtins.isString (o.path or null))
            || !(builtins.isString (o.text or null)) then
              throw "domains/${category}/${name}/render.nix: outputs must be { path, text, checks? }"
            else if !(lib.hasPrefix prefix o.path) then
              throw "domains/${category}/${name}/render.nix: output path '${o.path}' must be under '${prefix}'"
            else if o ? checks && !(builtins.isList o.checks) then
              throw "domains/${category}/${name}/render.nix: 'checks' must be a list"
            else
              o;
          checked = map check outs;
          pathCount = path: builtins.length (builtins.filter (o: o.path == path) checked);
          duplicate = lib.findFirst (path: pathCount path > 1) null (map (o: o.path) checked);
        in
        if duplicate != null then
          throw "domains/${category}/${name}/render.nix: duplicate output path '${duplicate}'"
        else
          checked;

      outputs =
        if !hasRender then
          [ ]
        else
          validateOutputs (
            render {
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
            }
          );

      isSkippable =
        subName: pathStr:
        subName == ".gitignore"
        || lib.hasInfix "/node_modules/" pathStr
        || lib.hasSuffix "/node_modules" pathStr
        || builtins.elem subName mutableBaseNames;

      go =
        dirPath: p:
        lib.concatLists (
          lib.mapAttrsToList (
            subName: subType:
            let
              fullPath = "${toString dirPath}/${subName}";
              relPath = p + subName;
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

      configSourceEntries =
        if hasConfigDir && hasXdg && !isCustomXdg then go configDir "" else [ ];

      xdgFileSourceEntries =
        if hasConfigDir && hasXdgFile && !isCustomXdg && !hasRender then
          [
            {
              target = meta.xdgFile;
              source = "${configDir}/${meta.xdgFile}";
            }
          ]
        else
          [ ];

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
          home.packages = lib.optionals (meta.package != null) [
            pkgs.${meta.package}
          ];
          home.file = lib.mkIf (hasRender && (!hasConfigDir || hasXdgFile || isCustomXdg)) renderedFiles;
        };
      };

      customModule = if home != null then home else { };

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

  mkNixosSystemModule = entry: entry.system or { };
in
{
  inherit mkDomainModule mkNixosSystemModule;
}
