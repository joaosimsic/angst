{
  lib,
  themesLib,
  renderDomainOutputsFor,
  testHostname,
}:

let
  themeNames = lib.attrNames themesLib.themes;

  themeResults = import ./entries.nix { inherit themesLib themeNames; };

  renderResults = lib.concatLists (
    map (
      themeName:
      map (output: "  ${output.path} render + ${themeName}: ok") (
        renderDomainOutputsFor testHostname themeName
      )
    ) themeNames
  );

  summary = lib.concatStringsSep "\n" (
    [
      "Themes (${toString (lib.length themeNames)}):"
    ]
    ++ themeResults
    ++ [
      ""
      "Domain renders:"
    ]
    ++ renderResults
    ++ [
      ""
      "All theme checks passed."
    ]
  );
in
summary
