{ config, themesLib }:
let
  t = themesLib.get config.theme;
  p = t.palette;
  inherit (t) isDark colorScheme;
in
rec {
  inherit
    t
    p
    isDark
    colorScheme
    ;
  toolbarThemeVal = if isDark then 1 else 0;
  contentThemeVal = if isDark then 1 else 0;
  contentOverrideVal = if isDark then 0 else 1;
  systemDarkVal = if isDark then 1 else 0;

  bg = "#${p.background.base}";
  bgVariant = "#${p.background.variant}";
  surface = "#${p.surface.base}";
  surfaceVariant = "#${p.surface.variant}";
  fg = "#${p.foreground.base}";
  fgVariant = "#${p.foreground.variant}";
  accent = "#${p.accent.base}";
  accentVariant = "#${p.accent.variant}";
  dim = "#${p.dim}";

  hoverBg = "color-mix(in srgb, var(--angst-fg) 10%, var(--angst-bg))";
  activeBg = "color-mix(in srgb, var(--angst-fg) 16%, var(--angst-bg))";
  hoverBgHex = "color-mix(in srgb, ${fg} 10%, ${bg})";
  activeBgHex = "color-mix(in srgb, ${fg} 16%, ${bg})";

  mkVar =
    name: value: important:
    "  --${name}: ${value}${if important then " !important" else ""};";

  mkVars =
    vars: important: builtins.concatStringsSep "\n" (map (v: mkVar v.name v.value important) vars);
}
