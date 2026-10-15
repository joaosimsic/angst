{ lib }:

let
  schema = import ./schema.nix { inherit lib; };
  color = import ./color.nix { inherit lib; };

  inherit (color)
    stripHash
    hexToRgb
    relativeLuminance
    contrastRatio
    ensureContrast
    ;

  themesDir = ./themes;

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
    lib.nameValuePair name (schema.validateOrThrow (import (themesDir + "/${filename}")))
  ) themeFiles;

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
    }
    // builtins.removeAttrs theme [
      "palette"
      "ansi"
    ];

  withRgb =
    theme:
    let
      walk =
        prefix: value:
        if builtins.isString value then
          { "${prefix}_RGB" = hexToRgb value; }
        else if builtins.isAttrs value then
          lib.concatMapAttrs (key: sub: walk "${prefix}_${key}" sub) value
        else
          { };
    in
    theme // walk "" theme;

  get =
    name:
    if themes ? ${name} then
      let
        raw = themes.${name};
        threshold = raw.contrastThreshold or 4.5;
        theme = withRgb (normalizeTheme raw);
        p = theme.palette;
        isDark = relativeLuminance p.background.base < 0.179;
        colorScheme = if isDark then "dark" else "light";
      in
      theme
      // {
        inherit isDark colorScheme;
        safe = {
          foregroundOnSurfaceVariant = ensureContrast {
            fg = p.foreground.variant;
            bg = p.surface.variant;
            fallback = p.background.base;
            inherit threshold;
          };
          foregroundOnSurfaceBase = ensureContrast {
            fg = p.foreground.variant;
            bg = p.surface.base;
            fallback = p.background.base;
            inherit threshold;
          };
          foregroundOnAccentVariant = ensureContrast {
            fg = p.foreground.variant;
            bg = p.accent.variant;
            fallback = p.background.base;
            inherit threshold;
          };
          foregroundOnAccentBase = ensureContrast {
            fg = p.foreground.variant;
            bg = p.accent.base;
            fallback = p.background.base;
            inherit threshold;
          };
          foregroundOnBgVariant = ensureContrast {
            fg = p.foreground.variant;
            bg = p.background.variant;
            fallback = p.background.base;
            inherit threshold;
          };
          surfaceVariantOnForegroundVariant =
            if contrastRatio p.surface.variant p.foreground.variant >= threshold then
              p.foreground.variant
            else
              p.background.base;
        };
      }
    else
      builtins.throw "Unknown theme '${name}'. Available themes: ${lib.concatStringsSep ", " (lib.attrNames themes)}";
in
{
  inherit
    themes
    get
    normalizeTheme
    withRgb
    ensureContrast
    contrastRatio
    relativeLuminance
    ;
  default = "monochrome";
}
