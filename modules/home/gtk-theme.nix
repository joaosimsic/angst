{
  lib,
  host,
  theme,
  themeSys,
  ...
}:

let
  t = themeSys.get theme;
  gtkTheme = if t.isDark then "Adwaita:dark" else "Adwaita";
  colorScheme = if t.isDark then "prefer-dark" else "default";
  preferDark = if t.isDark then "1" else "0";
in
{
  config = lib.mkIf (builtins.elem "desktop" host.profiles) {
    dconf.settings."org/gnome/desktop/interface" = {
      gtk-theme = lib.mkDefault "Adwaita";
      "color-scheme" = lib.mkDefault colorScheme;
    };

    xdg.configFile = {
      "gtk-3.0/settings.ini".text = lib.mkDefault ''
        [Settings]
        gtk-theme-name=Adwaita
        gtk-application-prefer-dark-theme=${preferDark}
      '';

      "gtk-4.0/settings.ini".text = lib.mkDefault ''
        [Settings]
        gtk-theme-name=Adwaita
        gtk-application-prefer-dark-theme=${preferDark}
      '';

      "xdg-desktop-portal/portals.conf".text = lib.mkDefault ''
        [preferred]
        default=gtk
      '';
    };

    home.sessionVariables.GTK_THEME = gtkTheme;
  };
}
