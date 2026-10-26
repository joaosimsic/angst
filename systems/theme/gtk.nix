{
  config,
  isDesktop,
  lib,
  themeSys,
  ...
}:

let
  t = themeSys.get config.theme;
  p = t.palette;
  gtkTheme = if t.isDark then "Adwaita:dark" else "Adwaita";
  colorScheme = if t.isDark then "dark" else "default";
  preferDark = if t.isDark then "1" else "0";
  textOn = t.safe.textOn;
  gtkCss = ''
    /* Generated from angst theme ${config.theme}; do not edit. */
    @define-color window_bg_color #${p.background.base};
    @define-color window_fg_color #${textOn p.background.base};
    @define-color headerbar_bg_color #${p.background.variant};
    @define-color headerbar_fg_color #${textOn p.background.variant};
    @define-color view_bg_color #${p.background.base};
    @define-color view_fg_color #${textOn p.background.base};
    @define-color accent_bg_color #${p.accent.base};
    @define-color accent_fg_color #${t.safe.foregroundOnAccentBase};
    @define-color accent_color #${p.accent.base};
    @define-color borders_color #${p.dim};
    @define-color destructive_bg_color #${t.ansi.error};
    @define-color destructive_fg_color #${textOn t.ansi.error};
    @define-color success_bg_color #${t.ansi.success};
    @define-color success_fg_color #${textOn t.ansi.success};
    @define-color warning_bg_color #${t.ansi.warn};
    @define-color warning_fg_color #${textOn t.ansi.warn};
  '';
in
{
  config = lib.mkIf isDesktop {
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

      "gtk-3.0/gtk.css".text = lib.mkDefault gtkCss;
      "gtk-4.0/gtk.css".text = lib.mkDefault gtkCss;
      "xdg-desktop-portal/portals.conf".text = lib.mkDefault ''
        [preferred]
        default=gtk
      '';
    };

    home.sessionVariables.GTK_THEME = gtkTheme;
  };
}
