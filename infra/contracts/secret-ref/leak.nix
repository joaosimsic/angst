let
  errors = import ./errors.nix;

  contains =
    needle: haystack:
    builtins.isString needle
    && needle != ""
    && builtins.isString haystack
    && haystack != builtins.replaceStrings [ needle ] [ "" ] haystack;

  jsonEncodedValue =
    value:
    let
      encoded = builtins.toJSON value;
    in
    builtins.substring 1 (builtins.stringLength encoded - 2) encoded;
in
{
  checkNoKnownSecrets =
    secrets: message: dataJSON:
    if !builtins.isList secrets then
      errors.throwError "checkNoKnownSecrets: `secrets` must be a list" { }
    else if !builtins.all (secret: builtins.isString secret && secret != "") secrets then
      errors.throwError "checkNoKnownSecrets: `secrets` must contain only non-empty strings" { }
    else if !(builtins.isString message && builtins.isString dataJSON) then
      errors.throwError "checkNoKnownSecrets: `message` and `dataJSON` must be strings" { }
    else if
      builtins.any (
        secret:
        contains secret message || contains secret dataJSON || contains (jsonEncodedValue secret) dataJSON
      ) secrets
    then
      errors.throwLeak { }
    else
      message;
}
