{ lib, domainsPath }:

let
  inherit (lib) concatLists mapAttrsToList optional;

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
                  hasRender = builtins.pathExists "${domainPath}/render.nix";
                in
                optional (buildingFilter building) {
                  inherit category name hasRender;
                  path = domainPath;
                  meta = meta // { inherit building; };
                }
            )
            (builtins.readDir categoryPath))
      )
      (builtins.readDir domainsPath));

  homeEntries = scanEntries (building: building == "home" || building == "both");
  nixosEntries = scanEntries (building: building == "nixos" || building == "both");
in
{
  inherit validateMeta scanEntries homeEntries nixosEntries;
}
