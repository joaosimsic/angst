let
  relativePathFor = prefix: basename: if prefix == "" then basename else prefix + "/" + basename;

  walkEntry =
    directory: prefix: entries: basename:
    let
      fileType = entries.${basename};
      relativePath = relativePathFor prefix basename;
    in
    if fileType == "directory" then
      walkDirectoryTree (directory + "/${basename}") relativePath
    else
      [
        {
          inherit basename fileType relativePath;
        }
      ];

  walkDirectoryTree =
    directory: prefix:
    let
      entries = builtins.readDir directory;
    in
    builtins.concatLists (
      map (basename: walkEntry directory prefix entries basename) (builtins.attrNames entries)
    );

  walkDir = root: walkDirectoryTree root "";
in
{
  inherit walkDir;
}
