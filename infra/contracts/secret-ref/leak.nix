let
  types = import ../../lib/types.nix;
  errors = import ./errors.nix;

  contains =
    needle: haystack:
    builtins.isString needle
    && needle != ""
    && builtins.isString haystack
    && haystack != builtins.replaceStrings [ needle ] [ "" ] haystack;

  jsonNeedle =
    value:
    let
      encoded = builtins.toJSON value;
    in
    builtins.substring 1 (builtins.stringLength encoded - 2) encoded;
in
{
  checkNoKnownSecrets =
    secrets: message: dataJson:
    let
      leaks =
        secret:
        contains secret message || contains secret dataJson || contains (jsonNeedle secret) dataJson;
    in
    if !builtins.isList secrets then
      errors.err "checkNoKnownSecrets: `secrets` must be a list" { }
    else if !builtins.all types.isNonEmptyStr secrets then
      errors.err "checkNoKnownSecrets: `secrets` must contain only non-empty strings" { }
    else if !(builtins.isString message && builtins.isString dataJson) then
      errors.err "checkNoKnownSecrets: `message` and `dataJson` must be strings" { }
    else if builtins.filter leaks secrets == [ ] then
      types.ok true
    else
      errors.leak { };
}
