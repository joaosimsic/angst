{
  lib,
  host,
  theme,
  themesLib,
  ...
}:

let
  t = themesLib.get theme;
  gtkTheme = if t.isDark then "Adwaita:dark" else "Adwaita";
  colorScheme = if t.isDark then "prefer-dark" else "default";
  preferDark = if t.isDark then "1" else "0";
in
{
  config = lib.mkIf (builtins.elem "desktop" host.profiles) {
    dconf.settings."org/gnome/desktop/interface" = {
      gtk-theme = "Adwaita";
      "color-scheme" = colorScheme;
    };

    xdg.configFile = {
      "gtk-3.0/settings.ini".text = ''
        [Settings]
        gtk-theme-name=Adwaita
        gtk-application-prefer-dark-theme=${preferDark}
      '';

      "gtk-4.0/settings.ini".text = ''
        [Settings]
        gtk-theme-name=Adwaita
        gtk-application-prefer-dark-theme=${preferDark}
      '';

      "xdg-desktop-portal/portals.conf".text = ''
        [preferred]
        default=gtk
      '';
    };

    home.sessionVariables.GTK_THEME = gtkTheme;
  };
}
