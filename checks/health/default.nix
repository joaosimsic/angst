{
  lib,
  pkgs,
  themesLib,
  render,
  host,
}:

let
  args = {
    inherit
      lib
      pkgs
      themesLib
      render
      host
      ;
  };

  dir = builtins.readDir ./.;

  healthFiles = builtins.filter (
    f:
    let
      t = dir.${f};
    in
    t == "regular" && lib.hasSuffix ".nix" f && f != "default.nix"
  ) (builtins.attrNames dir);

  importOne =
    f:
    let
      fn = import ./${f};
    in
    fn (lib.filterAttrs (n: _: builtins.hasAttr n (builtins.functionArgs fn)) args);

  attrsets = map importOne healthFiles;
in
lib.foldl' (acc: a: acc // a) { } attrsets
