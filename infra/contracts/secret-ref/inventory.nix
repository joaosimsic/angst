let
  types = import ../../lib/types.nix;
  strings = import ../../lib/strings.nix;
  errors = import ./errors.nix;

  suffixes = [
    ".age.placeholder"
    ".placeholder"
    ".age"
    ".pub"
  ];

  kindOf =
    suffix:
    if suffix == ".age" then
      "age"
    else if suffix == ".pub" then
      "pub"
    else
      "placeholder";

  dirOf =
    relPath: basename:
    let
      prefix = strings.stripSuffix basename relPath;
    in
    if prefix == "" then "" else strings.stripSuffix "/" prefix;

  parseSecretFile =
    entry:
    let
      matches = builtins.filter (suffix: strings.hasSuffix suffix entry.basename) suffixes;
      suffix = if matches == [ ] then null else builtins.head matches;
      slug = if suffix == null then "" else strings.stripSuffix suffix entry.basename;
    in
    if !(entry.ftype == "regular" || entry.ftype == "symlink") || suffix == null || slug == "" then
      null
    else
      {
        inherit slug suffix;
        kind = kindOf suffix;
        file = "secrets/" + entry.relPath;
        dir = dirOf entry.relPath entry.basename;
        inherit (entry) basename relPath;
      };

  sortEntries = builtins.sort (a: b: a.slug < b.slug || (a.slug == b.slug && a.file < b.file));

  mk =
    { hasDir, entries }:
    let
      parsed = sortEntries (builtins.filter (x: x != null) (map parseSecretFile entries));
      grouped = builtins.groupBy (entry: entry.slug) parsed;
      collisionFor =
        slug:
        let
          group = grouped.${slug};
          kinds = map (entry: entry.kind) group;
          dirs = strings.uniqueSorted (map (entry: entry.dir) group);
          allowed =
            builtins.length group == 2
            && builtins.elem "age" kinds
            && builtins.elem "pub" kinds
            && builtins.length dirs == 1;
        in
        if builtins.length group == 1 || allowed then
          null
        else
          {
            inherit slug;
            files = strings.uniqueSorted (map (entry: entry.file) group);
          };
      collisions = builtins.filter (x: x != null) (map collisionFor (builtins.attrNames grouped));
      result =
        if !hasDir then
          errors.err "SecretRef: secrets/ directory missing, no inventory" { path = "secrets"; }
        else if collisions != [ ] then
          errors.duplicate { duplicates = collisions; }
        else
          types.ok parsed;
      inventoryEntries = if types.isOk result then result.value else [ ];
      slugs = strings.uniqueSorted (map (entry: entry.slug) inventoryEntries);
      files = strings.uniqueSorted (map (entry: entry.file) inventoryEntries);
      empty = types.isOk result && inventoryEntries == [ ];
    in
    {
      inventoryResult = result;
      secretSlugs = slugs;
      secretFiles = files;
      secretInventory = {
        inherit slugs files;
      };
      isInventoryEmpty = empty;
      inventoryWarn =
        if empty then
          {
            level = "warn";
            code = "SEC002";
            message = "SecretRef: secrets/ empty, no secret files found";
            context = {
              path = "secrets";
            };
          }
        else
          null;
      checkInventory = types.mapOk (_: true) result;
    };
in
{
  inherit mk;
}
