{ lib, domainsPath }:

let
  inherit (lib) foldl' filter concatStringsSep attrNames concatLists mapAttrsToList optional;

  mkXdgSymlinks =
    { configDir, xdgName ? null, xdgFile ? null }:
    let
      isTemplate = name: builtins.match ".*\\.template$" name != null;

      joinPath = parts: concatStringsSep "/" (filter (p: p != "") parts);

      readDirRecursive = dir: relPath:
        let
          entries = builtins.readDir dir;
        in
        foldl' (acc: entryName:
          let
            fullPath = "${dir}/${entryName}";
            entry = entries.${entryName};
            xdgRel = joinPath [ relPath entryName ];
            xdgKey =
              if xdgName != null then
                joinPath [ xdgName xdgRel ]
              else
                xdgRel;
          in
          if entry == "directory" then
            acc // readDirRecursive fullPath xdgRel
          else if isTemplate entryName then
            acc
          else
            acc // {
              ${xdgKey} = {
                source = fullPath;
                force = true;
              };
            }
        ) { } (attrNames entries);
    in
    if xdgFile != null then
      {
        ${xdgFile} = {
          source = "${configDir}/${xdgFile}";
          force = true;
        };
      }
    else
      readDirRecursive configDir "";

  validateMeta = { category, name, meta }:
    let
      hasXdg = meta ? xdg;
      hasXdgFile = meta ? xdgFile;
    in
    if !(meta ? package) then
      builtins.throw "domains/${category}/${name}/meta.nix: missing required field 'package'"
    else if hasXdg && hasXdgFile then
      builtins.throw "domains/${category}/${name}/meta.nix: 'xdg' and 'xdgFile' are mutually exclusive"
    else if !hasXdg && !hasXdgFile then
      builtins.throw "domains/${category}/${name}/meta.nix: must set either 'xdg' or 'xdgFile'"
    else
      meta;

  homeEntries = concatLists (mapAttrsToList
    (category: catType:
      if catType != "directory" then
        [ ]
      else
        let
          categoryPath = "${domainsPath}/${category}";
        in
        concatLists (mapAttrsToList
          (name: nameType:
            if nameType != "directory" then
              [ ]
            else
              let
                domainPath = "${categoryPath}/${name}";
                rawMeta = import (domainPath + "/meta.nix");
                meta = validateMeta { inherit category name; meta = rawMeta; };
                building = meta.building or "home";
              in
              optional (building == "home") {
                inherit category name;
                path = domainPath;
                meta = meta // { inherit building; };
              }
          )
          (builtins.readDir categoryPath))
    )
    (builtins.readDir domainsPath));

  mkDomainModule = entry:
    let
      inherit (entry) category name meta path;

      modulePath = "${path}/module.nix";
      hasCustomModule = builtins.pathExists modulePath;

      baseModule =
        { config, lib, pkgs, ... }:
        let
          cfg = config.domains.${category}.${name};
          optionDescription = meta.description or "${name} configuration";
        in
        {
          options.domains.${category}.${name} = {
            enable = lib.mkEnableOption optionDescription;
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ pkgs.${meta.package} ];

            xdg.configFile = mkXdgSymlinks {
              configDir = "${path}/config";
              xdgName = meta.xdg or null;
              xdgFile = meta.xdgFile or null;
            };
          };
        };
    in
    {
      imports = [ baseModule ]
        ++ optional hasCustomModule (import modulePath);
    };
in
{
  inherit homeEntries mkDomainModule;
}
