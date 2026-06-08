{ lib }:

let
  inherit (lib) attrNames foldl' hasSuffix;

  hexToRgb = hex:
    let
      hexValues = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
      };
      hexByte = offset:
        let
          hi = lib.toLower (lib.substring offset 1 hex);
          lo = lib.toLower (lib.substring (offset + 1) 1 hex);
        in
        hexValues.${hi} * 16 + hexValues.${lo};
    in
    "${toString (hexByte 0)} ${toString (hexByte 2)} ${toString (hexByte 4)}";

  withRgb =
    theme:
    foldl'
      (acc: name:
        if hasSuffix "_RGB" name then
          acc
        else
          acc // {
            "${name}_RGB" = hexToRgb theme.${name};
          }
      )
      theme
      (attrNames theme);

  themes = {
    monochrome = import ./monochrome.nix;
  };
in
{
  inherit themes;

  default = "monochrome";

  get =
    name:
    if themes ? ${name} then
      withRgb themes.${name}
    else
      builtins.throw "Unknown theme: ${name}";
}
