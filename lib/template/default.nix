{ lib, themesLib, fontsLib ? import ../home/fonts.nix, domainsPath ? null }:

let
  renderTemplate = import ./render.nix;
  templatePlaceholders = import ./placeholders.nix { inherit lib; };
  discover = import ./discover.nix { inherit lib; };

  mkTokens =
    { theme, fontFamily ? fontsLib.defaultFamily }:
    import ./tokens.nix {
      inherit lib themesLib theme fontFamily;
    };

  resolve =
    if domainsPath != null then
      import ./resolve.nix {
        inherit lib domainsPath themesLib fontsLib mkTokens;
        inherit renderTemplate;
      }
    else
      { };
in
{
  inherit renderTemplate mkTokens;
  inherit (templatePlaceholders) extractPlaceholders;
  inherit (discover) findTemplates;
  inherit (resolve) resolveTemplatePath renderTemplateFor;
}
