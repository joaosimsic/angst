{
  config,
  lib,
  pkgs,
  store,
  themesLib ? null,
  ...
}:

let
  cfg = config.domains.design.paper;
  paperPkgRaw = pkgs.callPackage ./package.nix { };
  browserPkg = store.defaultBrowser or "firefox";
  isDark = if themesLib != null then (themesLib.get config.theme).isDark else true;
  ozoneHint = "x11";
  paperPkg = pkgs.symlinkJoin {
    name = "paper-desktop-wrapped";
    paths = [ paperPkgRaw ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/paper-desktop \
        --set BROWSER "${browserPkg}" \
        ${lib.optionalString isDark ''--add-flags "--force-dark-mode --enable-features=WebUIDarkMode,WebContentsForceDark --ozone-platform-hint=${ozoneHint}" --set ELECTRON_OZONE_PLATFORM_HINT ${ozoneHint} --set GTK_THEME Adwaita:dark''} \
        --run 'export XDG_DATA_DIRS="$HOME/.nix-profile/share:$HOME/.local/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"' \
        --run 'export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"'
    '';
  };
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ paperPkg ];

        xdg.desktopEntries.paper-desktop = {
          name = "Paper";
          genericName = "Design Tool";
          comment = "Paper Desktop – connected canvas (paper.design)";
          exec = "${paperPkg}/bin/paper-desktop %U";
          icon = "paper";
          categories = [
            "Graphics"
            "Development"
          ];
          mimeType = [ "x-scheme-handler/paper" ];
          startupNotify = true;
          terminal = false;
        };

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
