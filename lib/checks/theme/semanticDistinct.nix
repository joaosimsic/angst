{ lib, pkgs, themesLib, themeName }:

let
  theme = themesLib.get themeName;
  inherit (import ./assertions.nix { inherit lib themeName theme; }) requireDistinct;

  roles = [
    "ERROR"
    "SUCCESS"
    "WARNING"
    "INFO"
    "COMMENT"
    "MUTED"
  ];

  _ = requireDistinct "semantic roles" roles;
in
pkgs.writeText "theme-semantic-distinct-check" "ok"
