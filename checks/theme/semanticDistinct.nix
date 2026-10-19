{
  lib,
  pkgs,
  themesLib,
  themeName,
}:

let
  theme = themesLib.get themeName;
  inherit (import ./assertions.nix { inherit lib themeName theme; }) requireDistinct;

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
