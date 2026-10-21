{
  config,
  isDesktop,
  lib,
  pkgs,
  themeSys,
  ...
}:

let
  t = themeSys.get config.theme;

  csv = key: lib.replaceStrings [ " " ] [ "," ] t."_${key}";

  hexToCsv =
    hex:
    let
      h = lib.removePrefix "#" hex;
      byte = offset: lib.fromHexString (lib.substring offset 2 h);
    in
    "${toString (byte 0)},${toString (byte 2)},${toString (byte 4)}";

  section = bg: alternate: ''
    BackgroundNormal=${bg}
    BackgroundAlternate=${alternate}
    ForegroundNormal=${csv "palette_foreground_base_RGB"}
    ForegroundInactive=${csv "palette_dim_RGB"}
    ForegroundActive=${csv "palette_accent_base_RGB"}
    ForegroundLink=${csv "ansi_info_RGB"}
    ForegroundVisited=${csv "palette_accent_variant_RGB"}
    ForegroundNegative=${csv "ansi_error_RGB"}
    ForegroundNeutral=${csv "ansi_warn_RGB"}
    ForegroundPositive=${csv "ansi_success_RGB"}
    DecorationFocus=${csv "palette_accent_base_RGB"}
    DecorationHover=${csv "palette_accent_variant_RGB"}
  '';

  kdeglobals = ''
    [General]
    ColorScheme=${config.theme}
    Name=${config.theme}
    accentColor=${csv "palette_accent_base_RGB"}
    shadeSortColumn=true

    [Colors:Window]
    ${section (csv "palette_background_base_RGB") (csv "palette_background_variant_RGB")}

    [Colors:View]
    ${section (csv "palette_background_base_RGB") (csv "palette_background_variant_RGB")}

    [Colors:Button]
    ${section (csv "palette_background_variant_RGB") (csv "palette_background_base_RGB")}

    [Colors:Tooltip]
    ${section (csv "palette_background_variant_RGB") (csv "palette_background_base_RGB")}

    [Colors:Selection]
    BackgroundNormal=${csv "palette_accent_base_RGB"}
    BackgroundAlternate=${csv "palette_accent_variant_RGB"}
    ForegroundNormal=${hexToCsv t.safe.foregroundOnAccentBase}
    ForegroundInactive=${hexToCsv t.safe.foregroundOnAccentBase}
    ForegroundActive=${hexToCsv t.safe.foregroundOnAccentBase}
    ForegroundLink=${csv "ansi_info_RGB"}
    ForegroundVisited=${hexToCsv t.safe.foregroundOnAccentBase}
    ForegroundNegative=${csv "ansi_error_RGB"}
    ForegroundNeutral=${csv "ansi_warn_RGB"}
    ForegroundPositive=${csv "ansi_success_RGB"}
    DecorationFocus=${csv "palette_accent_base_RGB"}
    DecorationHover=${csv "palette_accent_variant_RGB"}

    [WM]
    activeBackground=${csv "palette_background_variant_RGB"}
    activeForeground=${csv "palette_foreground_base_RGB"}
    inactiveBackground=${csv "palette_background_base_RGB"}
    inactiveForeground=${csv "palette_dim_RGB"}

    [Icons]
    Theme=${if t.isDark then "breeze-dark" else "breeze"}
  '';
in
{
  config = lib.mkIf isDesktop {
    qt = {
      enable = true;
      platformTheme = {
        name = "kde";
        package = pkgs.kdePackages.plasma-integration;
      };
      style = {
        name = "breeze";
        package = pkgs.kdePackages.breeze;
      };
    };

    home.packages = [ pkgs.kdePackages.breeze-icons ];

    xdg.configFile."kdeglobals".text = kdeglobals;
  };
}
