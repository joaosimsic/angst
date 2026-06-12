{ lib, themeName, theme }:

let
  require =
    condition: message:
    if condition then
      null
    else
      throw message;

  requireDistinct =
    label: tokens:
    let
      values = map (token: theme.${token}) tokens;
    in
    require (lib.length values == lib.length (lib.unique values))
      "${themeName} ${label} must use distinct hues (duplicates among ${lib.concatStringsSep ", " tokens})";

  requireInfix =
    haystack: needle: message:
    require (lib.hasInfix needle haystack) message;
in
{
  inherit require requireDistinct requireInfix;
}
