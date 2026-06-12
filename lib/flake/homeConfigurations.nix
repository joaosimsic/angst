{ lib, hosts, mkHome, mkHomeWithExtraModules, themeContext }:

let
  inherit (themeContext) overrideTheme testHostname;

  perHost = lib.genAttrs
    (map (h: "joao@${h}") hosts)
    (name: mkHome (lib.removePrefix "joao@" name));
in
perHost // {
  joao = mkHome testHostname;
  joao-theme-override-test = mkHomeWithExtraModules testHostname [
    { theme = overrideTheme; }
  ];
}
