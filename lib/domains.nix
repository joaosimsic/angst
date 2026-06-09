{ lib, domainsPath }:

let
  inherit (lib) foldl' filter concatStringsSep attrNames concatLists mapAttrsToList optional removeSuffix;

  renderTemplate = import ./renderTemplate.nix;

  mkXdgSymlinks =
    { configDir, theme, xdgName ? null, xdgFile ? null }:
    let
      isTemplate = name: builtins.match ".*\\.template$" name != null;

      templateFor = name: "${name}.template";

      hasTemplate = dir: name:
        let
          entries = builtins.readDir dir;
        in
        entries ? ${templateFor name} && entries.${templateFor name} == "regular";

      joinPath = parts: concatStringsSep "/" (filter (p: p != "") parts);

      readDirRecursive = dir: relPath:
        let
          entries = builtins.readDir dir;
        in
        foldl' (acc: entryName:
          let
            fullPath = "${dir}/${entryName}";
            entry = entries.${entryName};
            xdgRel =
              if isTemplate entryName then
                joinPath [ relPath (removeSuffix ".template" entryName) ]
              else
                joinPath [ relPath entryName ];
            xdgKey =
              if xdgName != null then
                joinPath [ xdgName xdgRel ]
              else
                xdgRel;
          in
          if entry == "directory" then
            acc // readDirRecursive fullPath (joinPath [ relPath entryName ])
          else if isTemplate entryName then
            acc // {
              ${xdgKey} = {
                text = renderTemplate {
                  inherit lib;
                  templatePath = fullPath;
                  tokens = theme;
                };
                force = true;
              };
            }
          else if hasTemplate dir entryName then
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
      let
        templatePath = "${configDir}/${xdgFile}.template";
        filePath = "${configDir}/${xdgFile}";
      in
      if builtins.pathExists templatePath then
        {
          ${xdgFile} = {
            text = renderTemplate {
              inherit lib;
              inherit templatePath;
              tokens = theme;
            };
            force = true;
          };
        }
      else
        {
          ${xdgFile} = {
            source = filePath;
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

  mkDomainModule = entry: { config, lib, pkgs, hostTheme, themesLib, ... }:
  let
    inherit (entry) category name meta path;
    modulePath = "${path}/module.nix";
    hasCustomModule = builtins.pathExists modulePath;

    baseModule = {
      options.domains.${category}.${name} = {
        enable = lib.mkEnableOption "Enable ${meta.description or name}";
      };

      config = lib.mkIf config.domains.${category}.${name}.enable {
        xdg.configFile = mkXdgSymlinks {
          configDir = path;
          theme = themesLib.get hostTheme;
          xdgName = meta.xdg or null;
          xdgFile = meta.xdgFile or null;
        };
      };
    };

    customModule = if hasCustomModule then import modulePath else {};
  in
  {
    imports = [ baseModule customModule ];
  };
in
{
  inherit homeEntries mkDomainModule;
}
