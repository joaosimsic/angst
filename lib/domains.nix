{ lib, domainsPath }:

let
  inherit (lib) foldl' filter concatStringsSep attrNames concatLists mapAttrsToList optional removeSuffix;

  renderTemplate = import ./renderTemplate.nix;

  mkXdgSymlinks =
    { configDir, tokens, xdgName ? null, xdgFile ? null }:
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
                  inherit tokens;
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
              inherit tokens;
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
      customOnly = meta.customXdg or false;
    in
    if hasXdg && hasXdgFile then
      builtins.throw "domains/${category}/${name}/meta.nix: 'xdg' and 'xdgFile' are mutually exclusive"
    else if !hasXdg && !hasXdgFile && !customOnly then
      builtins.throw "domains/${category}/${name}/meta.nix: must set 'xdg', 'xdgFile', or 'customXdg = true'"
    else
      meta;

  scanEntries =
    buildingFilter:
    concatLists (mapAttrsToList
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
                optional (buildingFilter building) {
                  inherit category name;
                  path = domainPath;
                  meta = meta // { inherit building; };
                }
            )
            (builtins.readDir categoryPath))
      )
      (builtins.readDir domainsPath));

  homeEntries = scanEntries (building: building == "home" || building == "both");
  nixosEntries = scanEntries (building: building == "nixos" || building == "both");

  mkDomainModule = entry: { config, lib, pkgs, themesLib, ... }:
  let
    templateTokens = import ./templateTokens.nix;

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
        // lib.optionalAttrs (!(meta.customXdg or false)) {
          xdg.configFile = mkXdgSymlinks {
            inherit configDir;
            tokens = templateTokens {
              inherit lib themesLib;
              theme = config.theme;
              fontFamily = config.font.family;
            };
            xdgName = meta.xdg or null;
            xdgFile = meta.xdgFile or null;
          };
        }
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
  inherit homeEntries nixosEntries mkDomainModule mkNixosDomainModule;
}
