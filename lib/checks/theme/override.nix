{
  lib,
  pkgs,
  themesLib,
  overrideTheme,
  homeConfiguration,
  renderDomainOutputFor,
}:

let
  theme = homeConfiguration.config.theme;
  expected = themesLib.get overrideTheme;

  ghosttyColors =
    renderDomainOutputFor "personal" overrideTheme
      "domains/terminal/ghostty/config/colors.conf";
in
if theme != overrideTheme then
  throw "expected config.theme = ${overrideTheme}, got ${theme}"
else if !(lib.hasInfix "background           = ${expected.BG}" ghosttyColors) then
  throw "theme override did not reach rendered ghostty colors (expected ${overrideTheme} BG)"
else
  pkgs.writeText "theme-override-check" "ok"
