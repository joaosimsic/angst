{ lib, themesDir }:

let
  result = import ../../../lib/core/result.nix { inherit lib; };
  schema = import ./schema.nix { inherit lib; };

  isThemeFile =
    filename: type:
    type == "regular"
    && lib.hasSuffix ".nix" filename
    && !lib.hasPrefix "_" filename
    && filename != "default.nix"
    && filename != "schema.nix";

  filenames = lib.sort builtins.lessThan (
    builtins.attrNames (lib.filterAttrs isThemeFile (builtins.readDir themesDir))
  );

  load =
    filename:
    let
      id = lib.removeSuffix ".nix" filename;
      file = "systems/theme/themes/${filename}";
      checked = result.withContext { inherit file; } (schema.validate (import (themesDir + "/${filename}")));
    in
    {
      inherit file id checked;
    };

  loaded = map load filenames;
  entries = map (entry: {
    inherit (entry) id file;
    value = entry.checked.value;
  }) (builtins.filter (entry: entry.checked.ok) loaded);

  ids = map (entry: entry.id) entries;
  duplicateIds = builtins.filter (id: builtins.length (builtins.filter (other: other == id) ids) > 1) ids;

  duplicateDiagnostics = map (id: {
    kind = "catalog";
    message = "duplicate theme ID '${id}'";
    path = [ id ];
  }) (lib.unique duplicateIds);

  diagnostics =
    map (entry: entry.checked.error) (builtins.filter (entry: !entry.checked.ok) loaded)
    ++ duplicateDiagnostics;

  index = lib.listToAttrs (map (entry: lib.nameValuePair entry.id entry) entries);
in
{
  inherit
    entries
    index
    diagnostics
    ;
}
