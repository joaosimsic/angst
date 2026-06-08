{ lib }:

let
  inherit (lib)
    attrNames
    concatStringsSep
    elem
    filter
    genAttrs
    hasSuffix
    mapAttrs'
    nameValuePair
    removeSuffix
    ;

  schema = import ./schema.nix;
  inherit (schema) requiredTokens optionalTokens;
  allColorTokens = requiredTokens ++ optionalTokens;

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

  isValidHex = value: builtins.match "[0-9a-fA-F]{6}" value != null;

  validateTheme =
    name: theme:
    let
      missing = filter (t: !(theme ? ${t})) requiredTokens;
      definedColorKeys = filter (k: elem k allColorTokens && theme ? ${k}) (attrNames theme);
      invalid = filter (t: !isValidHex theme.${t}) definedColorKeys;
    in
    if missing != [ ] then
      builtins.throw "Theme '${name}' missing tokens: ${concatStringsSep ", " missing}"
    else if invalid != [ ] then
      builtins.throw "Theme '${name}' has invalid hex for: ${concatStringsSep ", " invalid}"
    else
      theme;

  withRgb =
    theme:
    let
      colorKeys = filter (k: elem k allColorTokens && theme ? ${k}) (attrNames theme);
    in
    theme
    // genAttrs (map (k: "${k}_RGB") colorKeys) (name:
      hexToRgb theme.${lib.removeSuffix "_RGB" name}
    );

  themesDir = ./.;
  themeFiles =
    lib.filterAttrs
      (filename: type:
        type == "regular"
        && hasSuffix ".nix" filename
        && filename != "default.nix"
        && filename != "schema.nix"
      )
      (builtins.readDir themesDir);

  themes =
    mapAttrs'
      (filename: _:
        let
          name = removeSuffix ".nix" filename;
        in
        nameValuePair name (import (themesDir + "/${filename}"))
      )
      themeFiles;
in
{
  inherit themes schema requiredTokens optionalTokens allColorTokens;

  default = "monochrome";

  get =
    name:
    if themes ? ${name} then
      withRgb (validateTheme name themes.${name})
    else
      builtins.throw "Unknown theme: ${name}";
}
