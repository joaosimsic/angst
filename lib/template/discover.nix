{ lib }:

let
  inherit (lib) concatLists hasSuffix mapAttrsToList;
in
rec {
  findTemplates =
    dir: relPath:
    let
      entries = builtins.readDir dir;
    in
    concatLists (mapAttrsToList
      (name: type:
        let
          fullPath = "${dir}/${name}";
          rel =
            if relPath == "" then
              name
            else
              "${relPath}/${name}";
        in
        if type == "directory" then
          findTemplates fullPath rel
        else if hasSuffix ".template" name then
          [ {
            inherit fullPath;
            inherit rel;
          } ]
        else
          [ ]
      )
      entries);
}
