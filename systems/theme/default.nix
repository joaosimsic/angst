{ lib }:

let
  color = import ./internal/color.nix { inherit lib; };
  catalog = import ./internal/catalog.nix {
    inherit lib;
    themesDir = ./themes;
  };
  normalize = import ./internal/normalize.nix {
    inherit lib;
    inherit (color) stripHash hexToRgb;
  };

  inherit (color)
    ensureContrast
    contrastRatio
    relativeLuminance
    ;

  inherit (normalize)
    normalizeTheme
    withRgb
    ;

  themes = lib.mapAttrs (_: entry: entry.value) catalog.index;

  checkHelpers =
    args:
    import ./internal/check-helpers.nix (
      {
        inherit lib;
      }
      // args
    );

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
  inherit (catalog)
    entries
    index
    diagnostics
    ;

  inherit
    themes
    get
    normalizeTheme
    withRgb
    checkHelpers
    ensureContrast
    contrastRatio
    relativeLuminance
    ;

  contrast = {
    inherit
      ensureContrast
      contrastRatio
      relativeLuminance
      ;
  };

  homeModules = [ ./home.nix ];
  default = "miasma";
}
