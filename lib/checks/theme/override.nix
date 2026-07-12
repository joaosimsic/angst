{
  lib,
  pkgs,
  themesLib,
  overrideTheme,
  homeConfiguration,
  renderDomainOutputFor,
  testHostname,
}:

let
  theme = homeConfiguration.config.theme;
  expected = themesLib.get overrideTheme;

  ghosttyColors =
    renderDomainOutputFor testHostname overrideTheme
      "domains/terminal/ghostty/config/colors.conf";
in
if theme != overrideTheme then
  throw "expected config.theme = ${overrideTheme}, got ${theme}"
else if !(lib.hasInfix "background           = ${expected.palette.background.variant}" ghosttyColors) then
  throw "theme override did not reach rendered ghostty colors (expected ${overrideTheme} background.variant)"
else
  pkgs.writeText "theme-override-check" "ok"
