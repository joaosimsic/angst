{
  lib,
  pkgs,
  domainsPath,
}:

let
  inherit (lib) concatLists mapAttrsToList;
  mkDomain = import ./mkDomain.nix { inherit lib pkgs; };

  isSingleLevelDomain = dir: builtins.pathExists (dir + "/default.nix");

  singleLevelEntries = concatLists (
    mapAttrsToList (
      name: type:
      if type != "directory" then
        [ ]
      else
        let
          domainPath = domainsPath + "/${name}";
          defaultPath = domainPath + "/default.nix";
        in
        if !(builtins.pathExists defaultPath) then
          [ ]
        else if !(isSingleLevelDomain domainPath) then
          [ ]
        else
          let
            hasSubDomains = builtins.any (n: builtins.pathExists (domainPath + "/${n}/default.nix")) (
              builtins.attrNames (builtins.readDir domainPath)
            );
          in
          if hasSubDomains then
            [ ]
          else
            [
              (mkDomain {
                inherit name;
                category = name;
                path = domainPath;
                spec = import defaultPath;
              })
            ]
    ) (builtins.readDir domainsPath)
  );

  twoLevelEntries = concatLists (
    mapAttrsToList (
      category: catType:
      if catType != "directory" then
        [ ]
      else
        let
          categoryPath = domainsPath + "/${category}";
          isSingle =
            builtins.pathExists (categoryPath + "/default.nix")
            && !(builtins.any (n: builtins.pathExists (categoryPath + "/${n}/default.nix")) (
              builtins.attrNames (builtins.readDir categoryPath)
            ));
        in
        if isSingle then
          [ ]
        else
          concatLists (
            mapAttrsToList (
              name: nameType:
              if nameType != "directory" then
                [ ]
              else
                let
                  domainPath = categoryPath + "/${name}";
                  defaultPath = domainPath + "/default.nix";
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

  scanEntries = singleLevelEntries ++ twoLevelEntries;

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
