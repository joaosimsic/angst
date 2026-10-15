{
  lib,
  pkgs,
  themesLib,
  renderDomainOutputsFor,
}:

let
  themeNames = lib.attrNames themesLib.themes;

  themeResults = import ./entries.nix { inherit themesLib themeNames; };

  unitResults =
    import ./color.nix { inherit lib; }
    ++ import ./schema.nix { inherit lib; }
    ++ import ./themes.nix { inherit lib themesLib; };

  renderResults = import ./render.nix {
    inherit
      lib
      pkgs
      themesLib
      renderDomainOutputsFor
      ;
  };

  summary = builtins.concatStringsSep "\n" (
    [
      "Themes (${toString (lib.length themeNames)}):"
    ]
    ++ themeResults
    ++ [
      ""
      "Theme unit tests:"
    ]
    ++ unitResults
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
builtins.deepSeq summary summary
