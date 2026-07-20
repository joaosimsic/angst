{
  lib,
  themeName,
  theme,
}:

let
  inherit (lib) attrByPath splitString;

  require = condition: message: if condition then null else throw message;

  getToken = token: attrByPath (splitString "." token) null theme;

  requireDistinct =
    label: tokens:
    let
      values = map getToken tokens;
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
