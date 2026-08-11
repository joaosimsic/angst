{
  lib,
  domainsPath,
}:

let
  inherit (lib) concatLists mapAttrsToList;

  validateMeta =
    {
      category,
      name,
      meta,
      hasSystem,
    }:
    let
      hasXdg = meta ? xdg;
      hasXdgFile = meta ? xdgFile;
      customOnly = meta.customXdg or false;
    in
    if hasXdg && hasXdgFile then
      builtins.throw "domains/${category}/${name}/meta.nix: 'xdg' and 'xdgFile' are mutually exclusive"
    else if !hasXdg && !hasXdgFile && !customOnly && !hasSystem then
      builtins.throw "domains/${category}/${name}/meta.nix: must set 'xdg', 'xdgFile', or 'customXdg = true' (system-only features must ship a system.nix)"
    else
      meta;

  scanEntries =
    concatLists (
      mapAttrsToList (
        category: catType:
        if catType != "directory" then
          [ ]
        else
          let
            categoryPath = "${domainsPath}/${category}";
          in
          concatLists (
            mapAttrsToList (
              name: nameType:
              if nameType != "directory" then
                [ ]
              else
                let
                  domainPath = "${categoryPath}/${name}";
                  rawMeta = import (domainPath + "/meta.nix");
                  hasSystem = builtins.pathExists "${domainPath}/system.nix";
                  hasHome = builtins.pathExists "${domainPath}/home.nix";
                  hasRender = builtins.pathExists "${domainPath}/render.nix";
                  hasConfigDir = builtins.pathExists "${domainPath}/config";
                  meta = validateMeta {
                    inherit category name hasSystem;
                    meta = rawMeta;
                  };
                in
                [
                  {
                    inherit
                      category
                      name
                      hasSystem
                      hasHome
                      hasRender
                      hasConfigDir
                      ;
                    path = domainPath;
                    inherit meta;
                  }
                ]
            ) (builtins.readDir categoryPath)
          )
      ) (builtins.readDir domainsPath)
    );

  entries = scanEntries;
  homeEntries = scanEntries;
  systemEntries = builtins.filter (e: e.hasSystem) scanEntries;
in
{
  inherit
    validateMeta
    scanEntries
    entries
    homeEntries
    systemEntries
    ;
}
