{ lib }:

let
  t = import "../core/types.nix" { inherit lib; };

  inherit (import "../core/evalSchema.nix.nix" { inherit lib; }) evalSchema;

  relPath = t.addCheck t.str (
    v: v != "" && !(lib.hasPrefix "/" v) && !(lib.hasPrefix "~" v) && !(lib.hasPrefix ".." v)
  );

  basename = t.addCheck t.str (v: v != "" && !(lib.hasInfix "/" v));

  schema = {
    package = t.option t.str;
    xdg = t.option t.str;
    xdgFile = t.option relPath;
    customXdg = t.optionOr t.bool false;
    description = t.option t.str;
    mutableFiles = t.option t.listOf basename;
  };

  validate = set: evalSchema schema set;
in
{
  inherit
    schema
    validate
    relPath
    basename
    ;
}
