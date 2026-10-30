{
  loadHost,
  themeSys,
  lib,
  testHostname ? "personal",
}:

let
  hostConfig = loadHost testHostname;
  hostTheme = hostConfig.theme or themeSys.default;

  alternateThemes = lib.sort lib.lessThan (
    lib.filter (name: name != hostTheme) (lib.attrNames themeSys.themes)
  );
in
{
  inherit testHostname hostTheme;

  overrideTheme =
    if alternateThemes == [ ] then
      builtins.throw "No alternate theme available for override test (host uses ${hostTheme})"
    else
      lib.head alternateThemes;
}
