{
  lib,
  pkgs,
  themesLib,
  renderDomainOutputsFor,
  themeName,
  testHostname,
}:

let
  theme = themesLib.get themeName;
  inherit (import ./assertions.nix { inherit lib themeName theme; })
    require
    requireDistinct
    requireInfix
    ;

  allOutputs = renderDomainOutputsFor testHostname themeName;

  themeChecks = [
    (requireDistinct "palette tokens" [
      "palette.dim"
      "palette.surface.variant"
      "palette.accent.base"
      "palette.foreground.base"
      "palette.surface.base"
      "palette.accent.variant"
    ])
  ];

  outputChecks = lib.concatMap (o: o.checks or [ ]) allOutputs;

  allChecks = themeChecks ++ outputChecks;
  _ = map (check: check) allChecks;
in
pkgs.writeText "theme-rendered-check" "ok"
