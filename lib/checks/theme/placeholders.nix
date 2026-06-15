{ lib, templateLib, templates, themeNames }:

let
  inherit (templateLib) mkTokens extractPlaceholders;
  inherit (lib) attrNames concatLists concatStringsSep elem filter;

  validate =
    { fullPath, rel }: themeName:
    let
      source = builtins.readFile fullPath;
      placeholders = extractPlaceholders source;
      tokens = mkTokens { theme = themeName; };
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
in
concatLists (map
  (template: map (validate template) themeNames)
  templates)
