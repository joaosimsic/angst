{ lib, templateLib, templates, themeNames }:

let
  inherit (templateLib) mkTokens renderTemplate extractPlaceholders themeTokenNames;
  inherit (lib) elem filter;

  validate =
    { fullPath, rel }: themeName:
    let
      source = builtins.readFile fullPath;
      placeholders = extractPlaceholders source;
      domainPlaceholders = filter (p: !(elem p themeTokenNames)) placeholders;
    in
    if domainPlaceholders != [ ] then
      "  ${rel} render + ${themeName}: skipped (domain tokens)"
    else
      let
        tokens = mkTokens { theme = themeName; };
        _ = renderTemplate {
          inherit lib;
          templatePath = fullPath;
          inherit tokens;
        };
      in
      "  ${rel} render + ${themeName}: ok";
in
lib.concatLists (map
  (template: map (validate template) themeNames)
  templates)
