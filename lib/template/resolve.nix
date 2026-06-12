{ lib, domainsPath, themesLib, fontsLib, mkTokens, renderTemplate }:

let
  resolveTemplatePath =
    relPath:
    let
      clean = lib.removePrefix "/" relPath;
      withSuffix = "${domainsPath}/${clean}.template";
      asPath = "${domainsPath}/${clean}";
    in
    if builtins.pathExists withSuffix then
      withSuffix
    else if lib.hasSuffix ".template" clean && builtins.pathExists asPath then
      asPath
    else
      builtins.throw "Template not found: ${clean} (tried ${withSuffix})";

  renderTemplateFor =
    templateRel: themeName:
    renderTemplate {
      inherit lib;
      templatePath = resolveTemplatePath templateRel;
      tokens = mkTokens { theme = themeName; };
    };
in
{
  inherit resolveTemplatePath renderTemplateFor;
}
