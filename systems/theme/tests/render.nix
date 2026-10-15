{
  lib,
  pkgs,
  themesLib,
  renderDomainOutputsFor,
}:

let
  inherit (import ./assert.nix { inherit lib; }) assertTrue;

  themeNames = lib.attrNames themesLib.themes;

  checkOne =
    themeName:
    let
      outputs = renderDomainOutputsFor themeName;
      allChecks = lib.concatMap (o: o.checks or [ ]) outputs;
      paths = map (o: o.path) outputs;
      hasGhostty = lib.any (p: p == "domains/terminal/ghostty/config/colors.conf") paths;
    in
    [
      (assertTrue "${themeName}: renders outputs" (lib.length outputs > 0))
      (assertTrue "${themeName}: ghostty colors rendered" hasGhostty)
      (builtins.deepSeq allChecks "  ${themeName}: ${toString (lib.length outputs)} outputs, checks ok")
    ];
in
lib.concatMap checkOne themeNames
