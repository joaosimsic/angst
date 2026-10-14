{ lib }:

let
  schema = import ./schema.nix { inherit lib; };

  themesDir = ./themes;
  entries = builtins.readDir themesDir;

  invalidEntries = lib.filterAttrs (
    filename: type: type != "regular" || !(lib.hasSuffix ".nix" filename)
  ) entries;

  checkedEntries =
    if invalidEntries != { } then
      throw "Invalid entries in ${toString themesDir}: ${lib.concatStringsSep "," (lib.attrNames invalidEntries)}, Expected regular nix files."
    else
      entries;

  loadTheme = filename:
    let
      name = lib.removeSuffix ".nix" filename;
      theme = import (themesDir + "/${filename}");
      validated = schema.validate theme;
    in
    if validated == null then

  themes = lib.mapAttrs' (
    filename: _:
    let
      name = lib.removeSuffix ".nix" filename;
    in
    lib.nameValuePair name (schema.validate (import (themesDir + "/${filename}")))
  ) themeFiles;
in
{
  inherit themes;
}
