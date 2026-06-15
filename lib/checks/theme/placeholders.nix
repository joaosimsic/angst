{ lib, templateLib, templates, themeNames }:

let
  inherit (templateLib) mkTokens extractPlaceholders themeTokenNames;
  inherit (lib) attrNames concatLists concatStringsSep elem filter;

  validate =
    { fullPath, rel }: themeName:
    let
      source = builtins.readFile fullPath;
      placeholders = extractPlaceholders source;
      themePlaceholders = filter (p: elem p themeTokenNames) placeholders;
      tokens = mkTokens { theme = themeName; };
      tokenKeys = attrNames tokens;
      missing = filter (p: !(elem p tokenKeys)) themePlaceholders;
    in
    if missing != [ ] then
      builtins.throw ''
        Template ${rel} references theme tokens missing from '${themeName}': ${concatStringsSep ", " missing}
        Theme placeholders: ${concatStringsSep ", " themePlaceholders}
        Available theme keys: ${concatStringsSep ", " tokenKeys}
      ''
    else
      "  ${rel} placeholders + ${themeName}: ok (${toString (lib.length themePlaceholders)} theme tokens)";
in
concatLists (map
  (template: map (validate template) themeNames)
  templates)
