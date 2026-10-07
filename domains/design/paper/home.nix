{
  config,
  lib,
  themesLib ? null,
  ...
}:

let
  cfg = config.domains.design.paper;
  isDark = if themesLib != null then (themesLib.get config.theme).isDark else true;
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        xdg.mimeApps = {
          enable = true;
          defaultApplications = {
            "x-scheme-handler/paper" = "paper-desktop.desktop";
            "x-scheme-handler/burp" = "install4j_1hv7l1i-BurpSuiteCommunity.desktop";
            "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
          };
          associations.added = {
            "x-scheme-handler/paper" = "paper-desktop.desktop";
            "x-scheme-handler/burp" = "install4j_1hv7l1i-BurpSuiteCommunity.desktop";
            "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
          };
        };
      }
      (lib.mkIf isDark {
        dconf.settings."org/gnome/desktop/interface" = {
          gtk-theme = "Adwaita-dark";
          color-scheme = "prefer-dark";
        };
        xdg.configFile."gtk-3.0/settings.ini".text = ''
          [Settings]
          gtk-application-prefer-dark-theme=1
          gtk-theme-name=Adwaita-dark
        '';
        xdg.configFile."xdg-desktop-portal/portals.conf".text = ''
          [preferred]
          default=gtk
        '';
      })
    ]
  );
}
