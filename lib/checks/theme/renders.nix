{ lib, templateLib, templates, themeNames }:

let
  inherit (templateLib) mkTokens renderTemplate;

  validate =
    { fullPath, rel }: themeName:
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
