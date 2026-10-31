let
  types = import ../lib/types.nix;
  fs = import ../lib/fs.nix;
  strings = import ../lib/strings.nix;

  secretsRoot = ../../secrets;
  hasSecretsDir = builtins.pathExists secretsRoot;

  stripSecretSuffix = name: strings.stripSuffixes [ ".placeholder" ".age" ".pub" ] name;

  isSecretFile = basename: ftype:
    (ftype == "regular" || ftype == "symlink")
    && (strings.hasSuffix ".age" basename || strings.hasSuffix ".placeholder" basename || strings.hasSuffix ".pub" basename);

  inventoryResult =
    if hasSecretsDir then
      let
        entries = fs.walkDir secretsRoot;
        kept = builtins.filter (e: isSecretFile e.basename e.ftype) entries;
      in
      types.ok (map (e: {
        slug = stripSecretSuffix e.basename;
        file = "secrets/" + e.relPath;
      }) kept)
    else
      types.err {
        kind = "secret";
        message = "SecretRef: secrets/ directory missing, no inventory";
        context = {
          path = "secrets";
        };
      };

  inventoryEntries = if types.isOk inventoryResult then inventoryResult.value else [ ];

  isInventoryEmpty = types.isOk inventoryResult && inventoryResult.value == [ ];

  inventoryWarn =
    if isInventoryEmpty then
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

  checkInventory = types.mapOk (_: true) inventoryResult;

  secretSlugs = strings.uniqueSorted (map (e: e.slug) inventoryEntries);

  secretFiles = strings.uniqueSorted (map (e: e.file) inventoryEntries);

  secretInventory = {
    slugs = secretSlugs;
    files = secretFiles;
  };

  isKnownSecretRef = ref: builtins.isString ref && ref != "" && builtins.elem ref secretSlugs;

  checkSecretRef =
    ref:
    if types.isErr inventoryResult then
      types.withContext { field = "ref"; } inventoryResult
    else if types.isNonEmptyStr ref && builtins.elem ref secretSlugs then
      types.ok { inherit ref; }
    else if !types.isNonEmptyStr ref then
      types.err {
        kind = "secret";
        message = "SecretRef: `ref` must be a non-empty string";
        context = {
          field = "ref";
        };
      }
    else
      types.err {
        kind = "secret";
        message = "SecretRef: unknown `ref`, no such slug under secrets/";
        context = {
          field = "ref";
          ref = ref;
        };
      };

  isSecretRef =
    v: builtins.isAttrs v && builtins.attrNames v == [ "ref" ] && types.isNonEmptyStr (v.ref or null);

  isScalar =
    v: v == null || builtins.isBool v || builtins.isInt v || builtins.isFloat v || builtins.isString v;

  checkUndeclaredRef =
    path: allowBare: v:
    if !isSecretRef v then
      types.err {
        kind = "secret";
        message = "SecretRef: `ref` must be a non-empty string";
        context = {
          inherit path;
        };
      }
    else if allowBare then
      types.ok true
    else
      types.err {
        kind = "secret";
        message = "SecretRef misplaced: allowed only under secret fields";
        context = {
          inherit path;
        };
      };

  checkDeclaredField =
    path: child:
    if types.isErr inventoryResult then
      inventoryResult
    else if isSecretRef child then
      if builtins.elem child.ref secretSlugs then
        types.ok true
      else
        types.err {
          kind = "secret";
          message = "SecretRef: unknown `ref`, no such slug under secrets/";
          context = {
            inherit path;
            ref = child.ref;
          };
        }
    else if builtins.isAttrs child && builtins.attrNames child == [ "ref" ] then
      types.err {
        kind = "secret";
        message = "SecretRef: `ref` must be a non-empty string";
        context = {
          inherit path;
        };
      }
    else
      types.err {
        kind = "secret";
        message = "secret field must be `SecretRef { ref }`, never a plain string";
        context = {
          path = path;
        };
      };

  checkOne =
    path: secretFields: parent: name:
    let
      child = parent.${name};
      sub = path + "." + name;
      declared = builtins.elem name secretFields || builtins.elem sub secretFields;
    in
    if declared then
      checkDeclaredField sub child
    else
      types.withContext { path = sub; } (checkValue sub false secretFields child);

  checkAttrs =
    path: secretFields: v:
    types.mapOk (_: true) (types.collect (map (checkOne path secretFields v) (builtins.attrNames v)));

  checkList =
    path: allowBare: secretFields: v:
    types.mapOk (_: true) (types.collect (map (checkValue path allowBare secretFields) v));

  checkValue =
    path: allowBare: secretFields: v:
    if isScalar v then
      types.ok true
    else if builtins.isList v then
      checkList path allowBare secretFields v
    else if builtins.isAttrs v && builtins.attrNames v == [ "ref" ] then
      checkUndeclaredRef path allowBare v
    else if builtins.isAttrs v then
      checkAttrs path secretFields v
    else
      types.err {
        kind = "secret";
        message = "SecretRef edge rejected: unsupported value type";
        context = {
          inherit path;
        };
      };

  checkSecretRefsIn =
    { data, secretFields ? secretSlugs }:
    if types.isErr inventoryResult then
      inventoryResult
    else
      checkValue "data" false secretFields data;

  # Deprecated alias: prefer `checkSecretRefsIn { data, secretFields }`.
  checkSecretRefsOnlyWith = args: checkSecretRefsIn ({ data = args.data; } // (if args ? secretKeys then { secretFields = args.secretKeys; } else { }) // (if args ? secretFields then { secretFields = args.secretFields; } else { }));

  checkSecretRefsOnly = data: checkSecretRefsIn { inherit data; };

  checkNoKnownSecrets =
    secrets: message: dataJson:
    let
      validSecrets = builtins.isList secrets;
      validInputs = builtins.isString message && builtins.isString dataJson;
      contains =
        needle: haystack:
        builtins.isString needle
        && needle != ""
        && builtins.isString haystack
        && haystack != builtins.replaceStrings [ needle ] [ "" ] haystack;
      bad = builtins.filter (s: contains s message || contains s dataJson) secrets;
    in
    if !validSecrets then
      types.err {
        kind = "secret";
        message = "checkNoKnownSecrets: `secrets` must be a list";
        context = { };
      }
    else if !validInputs then
      types.err {
        kind = "secret";
        message = "checkNoKnownSecrets: `message` and `dataJson` must be strings";
        context = { };
      }
    else if bad == [ ] then
      types.ok true
    else
      types.err {
        kind = "secret";
        message = "plain secret value present in message/data; wrap as `SecretRef` instead";
        context = { };
      };
in
{
  SecretRef = ref: types.unwrap (checkSecretRef ref);

  inherit checkSecretRef;

  inherit isSecretRef;

  inherit isKnownSecretRef;

  inherit secretSlugs;

  inherit secretFiles;

  inherit secretInventory;

  inherit hasSecretsDir;

  inherit inventoryResult;

  inherit isInventoryEmpty;

  inherit inventoryWarn;

  inherit checkInventory;

  inherit checkSecretRefsOnly;

  inherit checkSecretRefsIn;

  inherit checkSecretRefsOnlyWith;

  assertSecretRefsOnly = data: types.unwrap (checkSecretRefsOnly data);

  assertSecretRefsIn = args: types.unwrap (checkSecretRefsIn args);

  assertSecretRefsOnlyWith = args: types.unwrap (checkSecretRefsOnlyWith args);

  inherit checkNoKnownSecrets;

  assertNoKnownSecrets =
    secrets: message: dataJson:
    types.unwrap (checkNoKnownSecrets secrets message dataJson);
}
