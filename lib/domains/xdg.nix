{ lib }:

let
  inherit (lib) foldl' filter concatStringsSep attrNames removeSuffix;

  renderTemplate = import ../template/render.nix;

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
in
{
  inherit mkXdgSymlinks;
}
