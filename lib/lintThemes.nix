{ lib, themesLib, domainsPath }:

let
  fontsLib = import ./fonts.nix;
  templateTokens = import ./templateTokens.nix;

  inherit (lib)
    attrNames
    concatLists
    concatStringsSep
    elem
    filter
    hasSuffix
    mapAttrsToList
    ;

  renderTemplate = import ./renderTemplate.nix;
  templatePlaceholders = import ./templatePlaceholders.nix { inherit lib; };
  inherit (templatePlaceholders) extractPlaceholders;

  findTemplates =
    dir: relPath:
    let
      entries = builtins.readDir dir;
    in
    concatLists (mapAttrsToList
      (name: type:
        let
          fullPath = "${dir}/${name}";
          rel =
            if relPath == "" then
              name
            else
              "${relPath}/${name}";
        in
        if type == "directory" then
          findTemplates fullPath rel
        else if hasSuffix ".template" name then
          [ {
            inherit fullPath;
            rel = rel;
          } ]
        else
          [ ]
      )
      entries);

  templates = findTemplates domainsPath "";

  themeNames = attrNames themesLib.themes;

  validateThemeEntry =
    themeName:
    let
      _ = themesLib.get themeName;
    in
    "  ${themeName}: ok";

  validateTemplatePlaceholdersForTheme =
    { fullPath, rel }: themeName:
    let
      source = builtins.readFile fullPath;
      placeholders = extractPlaceholders source;
      tokens = templateTokens {
        inherit lib themesLib;
        theme = themeName;
        fontFamily = fontsLib.defaultFamily;
      };
      tokenKeys = attrNames tokens;
      missing = filter (p: !(elem p tokenKeys)) placeholders;
    in
    if missing != [ ] then
      builtins.throw ''
        Template ${rel} references tokens missing from theme '${themeName}': ${concatStringsSep ", " missing}
        Placeholders: ${concatStringsSep ", " placeholders}
        Available theme keys: ${concatStringsSep ", " tokenKeys}
      ''
    else
      "  ${rel} placeholders + ${themeName}: ok (${toString (lib.length placeholders)} tokens)";

  validateTemplateRenderForTheme =
    { fullPath, rel }: themeName:
    let
      tokens = templateTokens {
        inherit lib themesLib;
        theme = themeName;
        fontFamily = fontsLib.defaultFamily;
      };
      _ = renderTemplate {
        inherit lib;
        templatePath = fullPath;
        inherit tokens;
      };
    in
    "  ${rel} render + ${themeName}: ok";

  themeResults = map validateThemeEntry themeNames;

  placeholderResults = concatLists (map
    (template: map (validateTemplatePlaceholdersForTheme template) themeNames)
    templates);

  renderResults = concatLists (map
    (template: map (validateTemplateRenderForTheme template) themeNames)
    templates);

  summary = concatStringsSep "\n" ([
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
