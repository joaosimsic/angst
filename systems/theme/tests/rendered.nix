{
  lib,
  pkgs,
  themeSys,
  renderDomainOutputsFor,
  themeName,
}:

let
  theme = themeSys.get themeName;
  inherit (themeSys.checkHelpers { inherit themeName theme; }) requireDistinct;

  allOutputs = renderDomainOutputsFor themeName;

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
in
pkgs.writeText "theme-rendered-check" (builtins.seq (map (check: check) allChecks) "ok")
