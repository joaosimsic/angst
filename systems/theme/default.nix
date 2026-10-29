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
    pickContrast
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
        base = normalizeTheme raw;
        p = base.palette;
        isDark = relativeLuminance p.background.base < 0.179;
        colorScheme = if isDark then "dark" else "light";
        # Text candidates in intent order: light text first, then dark
        # surfaces. pickContrast keeps the first passing candidate and
        # falls back to the highest-ratio one when none pass.
        textOn =
          bg:
          pickContrast {
            candidates = [
              p.foreground.variant
              p.foreground.base
              p.background.base
              p.background.variant
            ];
            inherit bg threshold;
          };
        full = base // {
          inherit isDark colorScheme;
          safe = {
            foregroundOnSurfaceVariant = textOn p.surface.variant;
            foregroundOnSurfaceBase = textOn p.surface.base;
            foregroundOnAccentVariant = textOn p.accent.variant;
            foregroundOnAccentBase = textOn p.accent.base;
            foregroundOnBgVariant = textOn p.background.variant;
            surfaceVariantOnForegroundVariant = pickContrast {
              candidates = [
                p.foreground.variant
                p.background.base
              ];
              bg = p.surface.variant;
              inherit threshold;
            };
            # Arbitrary-bg text: textOn bg returns the first passing
            # candidate (intent order) or the highest-ratio one.
            inherit textOn;
          };
        };
      in
      # withRgb last so safe.* tokens get _RGB siblings too.
      withRgb full
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
    pickContrast
    contrastRatio
    relativeLuminance
    ;

  contrast = {
    inherit
      ensureContrast
      pickContrast
      contrastRatio
      relativeLuminance
      ;
  };

  homeModules = [ ./home.nix ];
  default = "miasma";
}
