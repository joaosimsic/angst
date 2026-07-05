{ lib, hosts, loadHost, mkHome, mkHomeWithExtraModules, themeContext }:

let
  inherit (themeContext) overrideTheme testHostname;

  perHost = lib.listToAttrs (map (h:
    let user = (loadHost h).user; in {
      name = "${user.username}@${h}";
      value = mkHome h;
    }
  ) hosts);
in
perHost // {
  "${(loadHost testHostname).user.username}" = mkHome testHostname;
  "${(loadHost testHostname).user.username}-theme-override-test" = mkHomeWithExtraModules testHostname [
    { theme = overrideTheme; }
  ];
}
