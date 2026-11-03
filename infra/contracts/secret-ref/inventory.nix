let
  strings = import ../../lib/strings.nix;
  errors = import ./errors.nix;

  suffixes = [
    ".age.placeholder"
    ".placeholder"
    ".age"
    ".pub"
  ];

  kindBySuffix = {
    ".age" = "age";
    ".pub" = "pub";
  };

  kindOf = suffix: kindBySuffix.${suffix} or "placeholder";

  secretParentDir =
    relativePath: basename:
    let
      prefix = strings.stripSuffix basename relativePath;
    in
    if prefix == "" then "" else strings.stripSuffix "/" prefix;

  parseSecretFile =
    entry:
    let
      matches = builtins.filter (suffix: strings.hasSuffix suffix entry.basename) suffixes;
      suffix = if matches == [ ] then null else builtins.head matches;
      slug = if suffix == null then "" else strings.stripSuffix suffix entry.basename;
    in
    if
      !(entry.fileType == "regular" || entry.fileType == "symlink") || suffix == null || slug == ""
    then
      null
    else
      {
        inherit slug suffix;
        kind = kindOf suffix;
        file = "secrets/" + entry.relativePath;
        dir = secretParentDir entry.relativePath entry.basename;
        inherit (entry) basename relativePath;
      };

  sortEntries = builtins.sort (
    left: right: left.slug < right.slug || (left.slug == right.slug && left.file < right.file)
  );

  parseEntries =
    entries:
    let
      parsedEntries = map parseSecretFile entries;
      secretEntries = builtins.filter (entry: entry != null) parsedEntries;
    in
    sortEntries secretEntries;

  collisionFor =
    grouped: slug:
    let
      group = grouped.${slug};
      kinds = map (entry: entry.kind) group;
      directories = strings.uniqueSorted (map (entry: entry.dir) group);
      allowed =
        builtins.length group == 2
        && builtins.elem "age" kinds
        && builtins.elem "pub" kinds
        && builtins.length directories == 1;
    in
    if builtins.length group == 1 || allowed then
      null
    else
      {
        inherit slug;
        files = strings.uniqueSorted (map (entry: entry.file) group);
      };

  collisionsFor =
    grouped:
    let
      slugs = builtins.attrNames grouped;
      collisions = map (slug: collisionFor grouped slug) slugs;
    in
    builtins.filter (collision: collision != null) collisions;

  mkSecretInventory =
    { hasDir, entries }:
    let
      parsed = parseEntries entries;
      grouped = builtins.groupBy (entry: entry.slug) parsed;
      collisions = collisionsFor grouped;
      inventoryEntries =
        if !hasDir then
          errors.throwMissingInventory { path = "secrets"; }
        else if collisions != [ ] then
          errors.throwDuplicate collisions
        else
          parsed;
      slugs = strings.uniqueSorted (map (entry: entry.slug) inventoryEntries);
      files = strings.uniqueSorted (map (entry: entry.file) inventoryEntries);
      empty = inventoryEntries == [ ];
    in
    {
      secretSlugs = slugs;
      secretFiles = files;
      secretInventory = { inherit slugs files; };
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
    };
in
{
  inherit mkSecretInventory;
}
