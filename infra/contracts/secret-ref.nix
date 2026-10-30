let
  types = import ../lib/types.nix;
  match = import ../lib/match.nix;

  checkSecretRef =
    ref:
    if types.isNonEmptyStr ref then
      types.ok { inherit ref; }
    else
      types.err {
        kind = "secret";
        message = "SecretRef: `ref` must be a non-empty string";
        context = {
          field = "ref";
        };
      };

  isSecretRef =
    v: builtins.isAttrs v && builtins.attrNames v == [ "ref" ] && types.isNonEmptyStr (v.ref or null);

  isSecretKey = name: match.isSecretKeyName name;

  isScalar =
    v: v == null || builtins.isBool v || builtins.isInt v || builtins.isFloat v || builtins.isString v;

  checkBareAttempt =
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
        message = "SecretRef misplaced: allowed only under secret keys";
        context = {
          inherit path;
        };
      };

  checkSecretField =
    path: child:
    if isSecretRef child then
      types.ok true
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
    path: parent: name:
    let
      child = parent.${name};
      sub = path + "." + name;
    in
    if match.isSecretKeyName name then
      checkSecretField sub child
    else
      types.withContext { path = sub; } (checkValue sub false child);

  checkAttrs =
    path: v: types.mapOk (_: true) (types.collect (map (checkOne path v) (builtins.attrNames v)));

  checkList =
    path: allowBare: v:
    types.mapOk (_: true) (types.collect (map (checkValue path allowBare) v));

  checkValue =
    path: allowBare: v:
    if isScalar v then
      types.ok true
    else if builtins.isList v then
      checkList path allowBare v
    else if builtins.isAttrs v && builtins.attrNames v == [ "ref" ] then
      checkBareAttempt path allowBare v
    else if builtins.isAttrs v then
      checkAttrs path v
    else
      types.err {
        kind = "secret";
        message = "SecretRef edge rejected: unsupported value type";
        context = {
          inherit path;
        };
      };

  checkSecretRefsOnly = data: checkValue "data" false data;

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

  inherit isSecretKey;

  inherit checkSecretRefsOnly;

  assertSecretRefsOnly = data: types.unwrap (checkSecretRefsOnly data);

  inherit checkNoKnownSecrets;

  assertNoKnownSecrets =
    secrets: message: dataJson:
    types.unwrap (checkNoKnownSecrets secrets message dataJson);
}
