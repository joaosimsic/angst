{ lib }:

let
  schema = import ./schema.nix;
  inherit (schema) paletteTokens subTokens ansiTokens;

  subPaths =
    layer: token:
    let
      pairs = map (sub: {
        path = [ layer token sub ];
        label = "${layer}.${token}.${sub}";
      }) subTokens;
    in
    pairs;

  dimPath = {
    path = [ "palette" "dim" ];
    label = "palette.dim";
  };

  ansiPaths = map (token: {
    path = [ "ansi" token ];
    label = "ansi.${token}";
  }) ansiTokens;

  requiredColorPaths =
    (lib.concatMap (token: subPaths "palette" token) paletteTokens)
    ++ [ dimPath ]
    ++ ansiPaths;

  stripHash = hex: if lib.hasPrefix "#" hex then lib.removePrefix "#" hex else hex;

  hexToRgb =
    hex:
    let
      h = stripHash hex;
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
      hexByte =
        offset:
        let
          hi = lib.toLower (lib.substring offset 1 h);
          lo = lib.toLower (lib.substring (offset + 1) 1 h);
        in
        hexValues.${hi} * 16 + hexValues.${lo};
    in
    "${toString (hexByte 0)} ${toString (hexByte 2)} ${toString (hexByte 4)}";

  isValidHex = value: builtins.match "[0-9a-fA-F]{6}" (stripHash value) != null;

  normalizeSub = sub: lib.mapAttrs (_: stripHash) sub;

  normalizeTheme =
    theme:
    let
      p = theme.palette;
    in
    {
      palette = {
        background = normalizeSub p.background;
        surface = normalizeSub p.surface;
        foreground = normalizeSub p.foreground;
        accent = normalizeSub p.accent;
        dim = stripHash p.dim;
      };
      ansi = lib.mapAttrs (_: stripHash) theme.ansi;
    };

  validateTheme =
    name: theme:
    let
      missing = lib.filter (entry: !(lib.hasAttrByPath entry.path theme)) requiredColorPaths;
      present = lib.filter (entry: lib.hasAttrByPath entry.path theme) requiredColorPaths;
      invalid = lib.filter (entry: !isValidHex (lib.attrByPath entry.path "" theme)) present;
    in
    if missing != [ ] then
      builtins.throw "Theme '${name}' missing tokens: ${
        lib.concatStringsSep ", " (map (entry: entry.label) missing)
      }"
    else if invalid != [ ] then
      builtins.throw "Theme '${name}' has invalid hex for: ${
        lib.concatStringsSep ", " (map (entry: entry.label) invalid)
      }"
    else
      theme;

  withRgb =
    theme:
    let
      walk = prefix: value:
        if builtins.isString value then
          { "${prefix}_RGB" = hexToRgb value; }
        else if builtins.isAttrs value then
          lib.concatMapAttrs (key: sub: walk "${prefix}_${key}" sub) value
        else
          { };
    in
    theme // walk "" theme;

  themesDir = ./.;
  themeFiles = lib.filterAttrs (
    filename: type:
    type == "regular"
    && lib.hasSuffix ".nix" filename
    && filename != "default.nix"
    && filename != "schema.nix"
  ) (builtins.readDir themesDir);

  themes = lib.mapAttrs' (
    filename: _:
    let
      name = lib.removeSuffix ".nix" filename;
    in
    lib.nameValuePair name (import (themesDir + "/${filename}"))
  ) themeFiles;
in
{
  inherit themes schema;

  default = "monochrome";

  get =
    name:
    if themes ? ${name} then
      withRgb (validateTheme name (normalizeTheme themes.${name}))
    else
      builtins.throw "Unknown theme: ${name}";
}
