{ lib, pkgs, themesLib, overrideTheme, homeConfiguration }:

let
  theme = homeConfiguration.config.theme;
  expected = themesLib.get overrideTheme;
  ghosttyColors = homeConfiguration.config.xdg.configFile."ghostty/colors.conf".text;
in
if theme != overrideTheme then
  throw "expected config.theme = ${overrideTheme}, got ${theme}"
else if !(lib.hasInfix "background           = ${expected.BG}" ghosttyColors) then
  throw "theme override did not reach rendered ghostty colors (expected ${overrideTheme} BG)"
else
  pkgs.writeText "theme-override-check" "ok"
