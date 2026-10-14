{ lib }:

let
  t = import "../../lib/core/types.nix" { inherit lib; };

  inherit (import ../core/evalSchema.nix { inherit lib; }) evalSchema;

  hexColor = t.addCheck t.str (value: builtins.match "[#][0-9a-fA-F]{6}" value != null);

  variants = t.set {
    base = hexColor;
    variant = hexColor;
  };

  schema = {
    palette = t.set {
      background = variants;
      surface = variants;
      foreground = variants;
      accent = variants;
      dim = hexColor;
    };

    ansi = t.set {
      error = hexColor;
      warn = hexColor;
      info = hexColor;
      success = hexColor;
    };

    contrastThreshold = t.optionOr t.number 4.5;
  };

  validate = set: evalSchema schema set;
in
{
  inherit hexColor validate schema;
}
