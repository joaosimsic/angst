let
  relPathFor = prefix: basename: if prefix == "" then basename else prefix + "/" + basename;

  walkOne = dir: prefix: entries: basename:
    let
      ftype = entries.${basename};
      relPath = relPathFor prefix basename;
    in
    if ftype == "directory" then walkGo (dir + "/${basename}") relPath else [
      {
        inherit basename relPath ftype;
      }
    ];

  walkGo = dir: prefix:
    let
      entries = builtins.readDir dir;
    in
    builtins.concatLists (map (walkOne dir prefix entries) (builtins.attrNames entries));

  walkDir = root: walkGo root "";
in
{
  inherit walkDir;
}
