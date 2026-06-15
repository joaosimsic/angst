 lib, themesLib, domainsPath }:

let
  templateLib = import ../../template/default.nix {
    inherit lib themesLib domainsPath;
  };

  inherit (templateLib) findTemplates;

  templates = findTemplates domainsPath "";
  themeNames = lib.attrNames themesLib.themes;

  common = {
    inherit lib templateLib templates themeNames;
  };

  themeResults = import ./entries.nix { inherit themesLib themeNames; };
  placeholderResults = import ./placeholders.nix common;
  renderResults = import ./renders.nix common;

  summary = lib.concatStringsSep "\n" ([
    "Themes (${toString (lib.length themeNames)}):"
  ]
  ++ themeResults
  ++ [
    ""
    "Template placeholders (${toString (lib.length templates)}):"
  ]
  ++ placeholderResults
  ++ [
    ""
    "Template renders (${toString (lib.length templates)}):"
  ]
  ++ renderResults
  ++ [
    ""
    "All theme checks passed."
  ]);
in
summary
