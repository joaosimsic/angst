{
  pkgs,
  themeSys,
  themeName,
}:

let
  theme = themeSys.get themeName;
  inherit (themeSys.checkHelpers { inherit themeName theme; }) requireDistinct;

  roles = [
    "ansi.error"
    "ansi.success"
    "ansi.warn"
    "ansi.info"
  ];
in
pkgs.writeText "theme-semantic-distinct-check" (
  builtins.seq (requireDistinct "semantic roles" roles) "ok"
)
