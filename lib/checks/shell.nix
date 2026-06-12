{ lib, pkgs, themesLib, renderTemplate, domainsPath }:

let
  templateLib = import ../template/default.nix { inherit lib themesLib domainsPath; };
  inherit (templateLib) mkTokens;

  themeNames = lib.attrNames themesLib.themes;

  renderForTheme =
    themeName:
    let
      tokens = mkTokens { theme = themeName; };
    in
    {
      inherit themeName;
      starship = renderTemplate {
        inherit lib;
        templatePath = "${domainsPath}/shell/starship/config/starship.toml.template";
        inherit tokens;
      };
      nushellColors = renderTemplate {
        inherit lib;
        templatePath = "${domainsPath}/shell/nushell/config/colors.nu.template";
        inherit tokens;
      };
    };

  rendered = map renderForTheme themeNames;

  checkTheme =
    { themeName, starship, nushellColors }:
    pkgs.runCommand "lint-shell-${themeName}" {
      nativeBuildInputs = [
        pkgs.taplo
        pkgs.nushell
      ];
    } ''
      echo "Validating starship config for theme ${themeName}..."
      cp ${pkgs.writeText "starship-${themeName}.toml" starship} starship.toml
      taplo check starship.toml

      echo "Validating nushell colors for theme ${themeName}..."
      cp ${pkgs.writeText "colors-${themeName}.nu" nushellColors} colors.nu
      nu -c "source colors.nu"

      touch $out
    '';
in
pkgs.linkFarm "lint-shell" (
  map (entry: {
    name = entry.themeName;
    path = checkTheme entry;
  }) rendered
)
