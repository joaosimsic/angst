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
    #sidebar-box {
      background-color: var(--angst-bg) !important;
      border-right: 1px solid var(--angst-surface) !important;
    }
    #sidebar {
      background-color: var(--angst-bg) !important;
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
  tridactylrc = ''
    set smoothscroll true
    set hintchars 1234567890
    bind j scrollline 10
    bind k scrollline -10
    bind h scrollpx -50
    bind l scrollpx 50
    bind gg scrolltop
    bind G scrollbottom
    bind d tabclose
    bind u undo
    bind r reload
    bind R reloadhard
    bind f hint
    bind F hint -b
    bind o fillcmdline open
    bind O fillcmdline tabopen
    bind b fillcmdline taball
    bind t fillcmdline tabopen
    bind / fillcmdline find
    bind n findnext 1
    bind N findnext -1
    bind gt tabnext
    bind gT tabprev
    bind <C-h> tabprev
    bind <C-l> tabnext
    bind gi focusinput -l
    bind --mode insert <C-c> mode normal
    bind --mode input <C-c> mode normal
    colours statusfg #${p.foreground.base}
    colours statusbg #${p.background.base}
    colours hintfg #${p.background.base}
    colours hintbg #${p.accent.base}
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
        ExtensionSettings = {
          "treestyletab@piro.sakura.ne.jp" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/treestyletab/latest.xpi";
          };
          "tridactyl.vim@cmcaine.co.uk" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/tridactyl-vim/latest.xpi";
          };
        };
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
        inherit userChrome;
        inherit userContent;
      };
    };
    home.file.".mozilla/firefox/default/tridactylrc".text = tridactylrc;
  };
}
