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

  hexToRgb =
    hex:
    let
      h = stripHash hex;
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

  hexToRgbInts = hex:
    let
      h = stripHash hex;
    in
    {
      r = hexValues.${lib.toLower (lib.substring 0 1 h)} * 16 + hexValues.${lib.toLower (lib.substring 1 1 h)};
      g = hexValues.${lib.toLower (lib.substring 2 1 h)} * 16 + hexValues.${lib.toLower (lib.substring 3 1 h)};
      b = hexValues.${lib.toLower (lib.substring 4 1 h)} * 16 + hexValues.${lib.toLower (lib.substring 5 1 h)};
    };

  srgbToLinearChannel = c:
    let cNorm = c / 255.0;
    in
    if cNorm <= 0.04045 then cNorm / 12.92
    else let x = (cNorm + 0.055) / 1.055; in x * x;

  relativeLuminance = hex:
    let
      rgb = hexToRgbInts (stripHash hex);
    in
    0.2126 * srgbToLinearChannel rgb.r
    + 0.7152 * srgbToLinearChannel rgb.g
    + 0.0722 * srgbToLinearChannel rgb.b;

  contrastRatio = hex1: hex2:
    let
      l1 = relativeLuminance hex1;
      l2 = relativeLuminance hex2;
      lighter = if l1 >= l2 then l1 else l2;
      darker = if l1 >= l2 then l2 else l1;
    in
    (lighter + 0.05) / (darker + 0.05);

  ensureContrast = { fg, bg, fallback, threshold ? 4.5 }:
    if contrastRatio fg bg >= threshold then fg else fallback;

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
    } // builtins.removeAttrs theme ["palette" "ansi"];

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
  inherit ensureContrast contrastRatio;

  default = "monochrome";

  get =
    name:
    if themes ? ${name} then
      let
        raw = themes.${name};
        threshold = raw.contrastThreshold or 4.5;
        theme = withRgb (validateTheme name (normalizeTheme raw));
        p = theme.palette;
      in
      theme // {
        safe = {
          foregroundOnSurfaceVariant = ensureContrast {
            fg = p.foreground.variant; bg = p.surface.variant; fallback = p.background.base;
            inherit threshold;
          };
          foregroundOnSurfaceBase = ensureContrast {
            fg = p.foreground.variant; bg = p.surface.base; fallback = p.background.base;
            inherit threshold;
          };
          foregroundOnAccentVariant = ensureContrast {
            fg = p.foreground.variant; bg = p.accent.variant; fallback = p.background.base;
            inherit threshold;
          };
          foregroundOnAccentBase = ensureContrast {
            fg = p.foreground.variant; bg = p.accent.base; fallback = p.background.base;
            inherit threshold;
          };
          foregroundOnBgVariant = ensureContrast {
            fg = p.foreground.variant; bg = p.background.variant; fallback = p.background.base;
            inherit threshold;
          };
          surfaceVariantOnForegroundVariant =
            if contrastRatio p.surface.variant p.foreground.variant >= threshold
            then p.foreground.variant
            else p.background.base;
        };
      }
    else
      builtins.throw "Unknown theme '${name}'. Available themes: ${
        lib.concatStringsSep ", " (builtins.attrNames themes)
      }";
}
