{ lib, pkgs, themesLib, renderDomainOutputFor }:

let
  themeNames = lib.attrNames themesLib.themes;

  renderForTheme =
    themeName:
    {
      inherit themeName;
      starship = renderDomainOutputFor "personal" themeName "domains/shell/starship/config/starship.toml";
      nushellColors = renderDomainOutputFor "personal" themeName "domains/shell/nushell/config/colors.nu";
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
