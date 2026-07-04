{ lib, pkgs, themesLib, renderDomainOutputsFor, themeName }:

let
  theme = themesLib.get themeName;
  inherit (import ./assertions.nix { inherit lib themeName theme; })
    require
    requireDistinct
    requireInfix
    ;

  allOutputs = renderDomainOutputsFor "personal" themeName;

  themeChecks = [
    (requireDistinct "palette tokens" [
      "RED"
      "GREEN"
      "YELLOW"
      "CYAN"
      "BLUE"
      "MAGENTA"
    ])
  ];

  outputChecks = lib.concatMap (o: o.checks or [ ]) allOutputs;

  allChecks = themeChecks ++ outputChecks;
  _ = map (check: check) allChecks;
in
pkgs.writeText "theme-rendered-check" "ok"
