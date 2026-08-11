{
  lib,
  pkgs,
  domainsPath,
}:

let
  inherit (lib) concatLists mapAttrsToList;
  mkDomain = import ./mkDomain.nix { inherit lib pkgs; };

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
                  defaultPath = "${domainPath}/default.nix";
                in
                if !(builtins.pathExists defaultPath) then
                  builtins.throw "domains/${category}/${name}: missing default.nix"
                else
                  [
                    (mkDomain {
                      inherit category name;
                      path = domainPath;
                      spec = import defaultPath;
                    })
                  ]
            ) (builtins.readDir categoryPath)
          )
      ) (builtins.readDir domainsPath)
    );

  entries = scanEntries;
  homeEntries = entries;
  systemEntries = builtins.filter (e: e.hasSystem) entries;
in
{
  inherit
    mkDomain
    scanEntries
    entries
    homeEntries
    systemEntries
    ;
}
