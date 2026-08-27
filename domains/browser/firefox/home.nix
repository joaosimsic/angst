{
  config,
  lib,
  pkgs,
  themesLib,
  ...
}:
let
  cfg = config.domains.browser.firefox;
  t = themesLib.get config.theme;
  p = t.palette;
  userChrome = ''
    :root {
      --angst-bg: #${p.background.base};
      --angst-bg-variant: #${p.background.variant};
      --angst-surface: #${p.surface.base};
      --angst-surface-variant: #${p.surface.variant};
      --angst-fg: #${p.foreground.base};
      --angst-fg-variant: #${p.foreground.variant};
      --angst-accent: #${p.accent.base};
      --angst-accent-variant: #${p.accent.variant};
      --angst-dim: #${p.dim};
    }
    #navigator-toolbox {
      background-color: var(--angst-bg) !important;
      color: var(--angst-fg) !important;
      border-bottom: 1px solid var(--angst-surface) !important;
    }
    #TabsToolbar, #nav-bar {
      background: var(--angst-bg) !important;
    }
    .tabbrowser-tab[selected="true"] .tab-background {
      background: var(--angst-surface) !important;
    }
    .tabbrowser-tab[selected="true"] .tab-label {
      color: var(--angst-fg) !important;
    }
    #urlbar-background {
      background: var(--angst-bg-variant) !important;
      border-color: var(--angst-surface) !important;
    }
  '';
  userContent = ''
    @-moz-document url("about:blank"), url("about:home"), url("about:newtab") {
      body {
        background-color: #${p.background.base} !important;
        color: #${p.foreground.base} !important;
      }
      a { color: #${p.accent.base} !important; }
    }
  '';
in
{
  config = lib.mkIf cfg.enable {
    programs.firefox = {
      enable = true;
      package = pkgs.firefox;
      configPath = ".mozilla/firefox";
      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        DontCheckDefaultBrowser = true;
        DisableAppUpdate = true;
        DisplayBookmarksToolbar = "never";
        OfferToSaveLogins = false;
        ExtensionSettings = { };
      };
      profiles.default = {
        id = 0;
        name = "default";
        isDefault = true;
        settings = {
          "browser.startup.homepage" = "about:blank";
          "browser.toolbars.bookmarks.visibility" = "never";
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "browser.uidensity" = 0;
          "browser.theme.toolbar-theme" = 0;
        };
        userChrome = userChrome;
        userContent = userContent;
      };
    };
  };
}
