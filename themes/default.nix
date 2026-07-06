{ lib }:

let
  inherit (lib)
    attrNames
    concatStringsSep
    filter
    genAttrs
    hasAttrByPath
    hasSuffix
    attrByPath
    mapAttrs'
    nameValuePair
    removeSuffix
    ;

  schema = import ./schema.nix;
  inherit (schema)
    ansiTokens
    paletteTokens
    uiTokens
    syntaxTokens
    diagnosticTokens
    legacyTokens
    ;

  layerPaths =
    layer: tokens:
    map (token: {
      path = [
        layer
        token
      ];
      label = "${layer}.${token}";
    }) tokens;

  ansiPaths =
    variant: tokens:
    map (token: {
      path = [
        "ansi"
        variant
        token
      ];
      label = "ansi.${variant}.${token}";
    }) tokens;

  requiredColorPaths =
    (layerPaths "palette" paletteTokens)
    ++ (ansiPaths "normal" ansiTokens)
    ++ (ansiPaths "bright" ansiTokens)
    ++ (layerPaths "ui" uiTokens)
    ++ (layerPaths "syntax" syntaxTokens)
    ++ (layerPaths "diagnostic" diagnosticTokens);

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

  normalizeLayer = layer: lib.mapAttrs (_: stripHash) layer;

  normalizeThemeColors =
    theme:
    theme
    // {
      palette = normalizeLayer theme.palette;
      ansi = {
        normal = normalizeLayer theme.ansi.normal;
        bright = normalizeLayer theme.ansi.bright;
      };
      ui = normalizeLayer theme.ui;
      syntax = normalizeLayer theme.syntax;
      diagnostic = normalizeLayer theme.diagnostic;
    };

  validateTheme =
    name: theme:
    let
      missing = filter (entry: !(hasAttrByPath entry.path theme)) requiredColorPaths;
      present = filter (entry: hasAttrByPath entry.path theme) requiredColorPaths;
      invalid = filter (entry: !isValidHex (attrByPath entry.path "" theme)) present;
    in
    if missing != [ ] then
      builtins.throw "Theme '${name}' missing tokens: ${
        concatStringsSep ", " (map (entry: entry.label) missing)
      }"
    else if invalid != [ ] then
      builtins.throw "Theme '${name}' has invalid hex for: ${
        concatStringsSep ", " (map (entry: entry.label) invalid)
      }"
    else
      theme;

  withRgb =
    theme:
    let
      colorKeys = filter (k: builtins.isString theme.${k}) (attrNames theme);
    in
    theme
    // genAttrs (map (k: "${k}_RGB") colorKeys) (name: hexToRgb theme.${lib.removeSuffix "_RGB" name});

  withAliases =
    theme:
    let
      inherit (theme) palette;
      inherit (theme.ansi) normal bright;
      inherit (theme) ui syntax diagnostic;
    in
    theme
    // {
      FG = ui.fg;
      BG = ui.bg;
      BRIGHT = ui.bright;
      MUTED = ui.muted;
      COMMENT = syntax.comment;
      ERROR = diagnostic.error;
      SUCCESS = diagnostic.success;
      WARNING = diagnostic.warning;
      INFO = diagnostic.info;

      BLACK = normal.black;
      RED = normal.red;
      GREEN = normal.green;
      YELLOW = normal.yellow;
      CYAN = normal.cyan;
      BLUE = normal.blue;
      MAGENTA = normal.magenta;
      BASE = palette.base;
      DIM = palette.dim;
      SUBTLE = ui.subtle;
      ACCENT = ui.accent;
      SURFACE = ui.surface;

      RED_BRIGHT = bright.red;
      GREEN_BRIGHT = bright.green;
      YELLOW_BRIGHT = bright.yellow;
      BLUE_BRIGHT = bright.blue;
      MAGENTA_BRIGHT = bright.magenta;
      CYAN_BRIGHT = bright.cyan;
    };

  themesDir = ./.;
  themeFiles = lib.filterAttrs (
    filename: type:
    type == "regular"
    && hasSuffix ".nix" filename
    && filename != "default.nix"
    && filename != "schema.nix"
  ) (builtins.readDir themesDir);

  themes = mapAttrs' (
    filename: _:
    let
      name = removeSuffix ".nix" filename;
    in
    nameValuePair name (import (themesDir + "/${filename}"))
  ) themeFiles;
in
{
  inherit
    themes
    schema
    ansiTokens
    paletteTokens
    uiTokens
    syntaxTokens
    diagnosticTokens
    legacyTokens
    requiredColorPaths
    ;

  default = "monochrome";

  get =
    name:
    if themes ? ${name} then
      withRgb (withAliases (validateTheme name (normalizeThemeColors themes.${name})))
    else
      builtins.throw "Unknown theme: ${name}";
}
