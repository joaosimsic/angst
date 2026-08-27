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
  isDark = themesLib.relativeLuminance p.background.base < 0.179;
  colorScheme = if isDark then "dark" else "light";
  toolbarThemeVal = if isDark then 1 else 0;
  contentThemeVal = if isDark then 1 else 0;
  contentOverrideVal = if isDark then 0 else 1;
  systemDarkVal = if isDark then 1 else 0;
  userChrome = ''
    :root {
      color-scheme: ${colorScheme} !important;
      --angst-bg: #${p.background.base};
      --angst-bg-variant: #${p.background.variant};
      --angst-surface: #${p.surface.base};
      --angst-surface-variant: #${p.surface.variant};
      --angst-fg: #${p.foreground.base};
      --angst-fg-variant: #${p.foreground.variant};
      --angst-accent: #${p.accent.base};
      --angst-accent-variant: #${p.accent.variant};
      --angst-dim: #${p.dim};
      --lwt-accent-color: var(--angst-bg) !important;
      --lwt-text-color: var(--angst-fg) !important;
      --toolbar-bgcolor: var(--angst-bg) !important;
      --toolbar-color: var(--angst-fg-variant) !important;
      --toolbarbutton-icon-fill: var(--angst-fg) !important;
      --arrowpanel-background: var(--angst-bg-variant) !important;
      --arrowpanel-color: var(--angst-fg-variant) !important;
      --arrowpanel-border-color: var(--angst-surface) !important;
      --panel-background: var(--angst-bg) !important;
      --panel-color: var(--angst-fg-variant) !important;
      --urlbarView-result-color: var(--angst-fg) !important;
      --urlbarView-highlight-background: var(--angst-surface) !important;
      --urlbarView-highlight-color: var(--angst-fg-variant) !important;
      --urlbarView-hover-background: var(--angst-surface-variant) !important;
      --toolbar-field-background-color: var(--angst-bg-variant) !important;
      --toolbar-field-color: var(--angst-fg-variant) !important;
      --toolbar-field-border-color: var(--angst-surface) !important;
      --toolbar-field-focus-background-color: var(--angst-bg-variant) !important;
      --toolbar-field-focus-color: var(--angst-fg-variant) !important;
      --toolbar-field-focus-border-color: var(--angst-accent) !important;
      --lwt-toolbar-field-background-color: var(--angst-bg-variant) !important;
      --lwt-toolbar-field-color: var(--angst-fg-variant) !important;
      --lwt-toolbar-field-focus: var(--angst-bg-variant) !important;
      --lwt-toolbar-field-focus-color: var(--angst-fg-variant) !important;
      --toolbar-field-highlight: var(--angst-accent) !important;
      --toolbar-field-highlight-text: var(--angst-bg) !important;
    }
    #navigator-toolbox {
      background-color: var(--angst-bg) !important;
      color: var(--angst-fg) !important;
      border-bottom: 1px solid var(--angst-surface) !important;
    }
    #TabsToolbar {
      visibility: collapse !important;
    }
    #nav-bar {
      background: var(--angst-bg) !important;
    }
    .tabbrowser-tab[selected="true"] .tab-background {
      background: var(--angst-surface) !important;
    }
    .tabbrowser-tab[selected="true"] .tab-label {
      color: var(--angst-fg-variant) !important;
    }
    #urlbar, #urlbar * {
      --toolbar-field-background-color: var(--angst-bg-variant) !important;
      --toolbar-field-focus-background-color: var(--angst-bg-variant) !important;
    }
    /* unfocused bar */
    #urlbar-background, #searchbar {
      background-color: var(--angst-bg-variant) !important;
      background: var(--angst-bg-variant) !important;
      border-color: var(--angst-surface) !important;
      box-shadow: none !important;
    }
    /* focused/breakout – the single .urlbar-background paints both input and dropdown */
    #urlbar[focused] > #urlbar-background,
    #urlbar[open] > #urlbar-background,
    #urlbar[breakout][breakout-extend] > #urlbar-background,
    #urlbar[breakout][breakout-extend][open] > #urlbar-background,
    .urlbar-background, #searchbar:focus-within {
      background-color: var(--angst-bg) !important;
      background: var(--angst-bg) !important;
      border-color: var(--angst-surface) !important;
      box-shadow: none !important;
    }
    #urlbar[focused] > #urlbar-background { border-color: var(--angst-accent) !important; }
    #urlbar[breakout][breakout-extend] { background: transparent !important; }
    #urlbar-input, #urlbar-input::placeholder, .urlbar-input, #searchbar input {
      color: var(--angst-fg-variant) !important;
    }
    #urlbarView, .urlbarView-body-inner, #urlbar-results {
      background: var(--angst-bg) !important;
      background-color: var(--angst-bg) !important;
      color: var(--angst-fg) !important;
      border: 1px solid var(--angst-surface) !important;
      border-top: none !important;
    }
    .urlbarView-row-inner, .urlbarView-no-wrap, .urlbarView-title, .urlbarView-url, .urlbarView-action, .urlbarView-type-icon {
      color: var(--angst-fg) !important;
    }
    .urlbarView-row[selected] > .urlbarView-row-inner, .urlbarView-row:hover > .urlbarView-row-inner {
      background: var(--urlbarView-highlight-background) !important;
      color: var(--urlbarView-highlight-color) !important;
    }
    .urlbarView-row[selected] .urlbarView-title, .urlbarView-row[selected] .urlbarView-url,
    .urlbarView-row[selected] .urlbarView-action {
      color: var(--urlbarView-highlight-color) !important;
    }
    #sidebar-box {
      background-color: var(--angst-bg) !important;
      border-right: 1px solid var(--angst-surface) !important;
    }
    #sidebar {
      background-color: var(--angst-bg) !important;
    }
    panel, menupopup, .panel-arrowcontent {
      background: var(--angst-bg-variant) !important;
      color: var(--angst-fg-variant) !important;
    }
    #findbar {
      background: var(--angst-bg-variant) !important;
      border-top: 1px solid var(--angst-surface) !important;
    }
  '';
  userContent = ''
    @-moz-document url-prefix("about:") {
      html {
        color-scheme: ${colorScheme} !important;
      }
      body {
        background-color: #${p.background.base} !important;
        color: #${p.foreground.base} !important;
      }
      a { color: #${p.accent.base} !important; }
    }
    @-moz-document url("about:blank"), url("about:home"), url("about:newtab") {
      body {
        background-color: #${p.background.base} !important;
        color: #${p.foreground.base} !important;
      }
      a { color: #${p.accent.base} !important; }
    }
    @-moz-document url-prefix("moz-extension://") {
      :root {
        --tridactyl-fg: #${p.foreground.base} !important;
        --tridactyl-bg: #${p.background.base} !important;
        --tridactyl-url-fg: #${p.accent.base} !important;
        --tridactyl-url-bg: #${p.background.base} !important;
        --tridactyl-highlight-box-bg: #${p.surface.base} !important;
        --tridactyl-highlight-box-fg: #${p.foreground.variant} !important;
        --tridactyl-of-fg: #${p.foreground.variant} !important;
        --tridactyl-of-bg: #${p.surface.variant} !important;
        --tridactyl-cmdl-fg: #${p.foreground.variant} !important;
        --tridactyl-cmdl-bg: #${p.background.variant} !important;
        --tridactyl-cmplt-bg: #${p.background.base} !important;
        --tridactyl-cmplt-fg: #${p.foreground.base} !important;
        --tridactyl-cmplt-border-top: 1px solid #${p.surface.base} !important;
        --tridactyl-status-fg: #${p.foreground.base} !important;
        --tridactyl-status-bg: #${p.background.base} !important;
        --tridactyl-status-border: 1px solid #${p.surface.base} !important;
        --tridactyl-hint-fg: #${p.background.base} !important;
        --tridactyl-hint-bg: #${p.accent.base} !important;
        --tridactyl-hint-outline: 1px solid #${p.accent.variant} !important;
        --tridactyl-hint-active-fg: #${p.background.base} !important;
        --tridactyl-hint-active-bg: #${p.accent.variant} !important;
        --tridactyl-hintspan-fg: #${p.background.base} !important;
        --tridactyl-hintspan-bg: #${p.accent.base} !important;
        --tridactyl-scrollbar-color: #${p.surface.base} #${p.background.base} !important;
        --tridactyl-photon-colours-accent-1: #${p.accent.base} !important;
        --tridactyl-photon-colours-accent-2: #${p.accent.variant} !important;
        --tridactyl-photon-colours-in-content-page-background: #${p.background.base} !important;
        --tridactyl-photon-colours-in-content-page-color: #${p.foreground.base} !important;
        --tridactyl-photon-colours-cm-background: #${p.background.variant} !important;
        --tridactyl-photon-colours-cm-selection: #${p.surface.base} !important;
      }
      #command-line-holder { border: 1px solid #${p.surface.base} !important; background: var(--tridactyl-cmdl-bg) !important; }
      #tridactyl-input { color: var(--tridactyl-cmdl-fg) !important; background: var(--tridactyl-cmdl-bg) !important; }
      #completions { color: var(--tridactyl-cmplt-fg) !important; background: var(--tridactyl-cmplt-bg) !important; border-top: var(--tridactyl-cmplt-border-top) !important; }
      #completions .focused, #completions .focused .url { background: #${p.accent.base} !important; color: #${p.background.base} !important; }
      .TridactylStatusIndicator { background: var(--tridactyl-status-bg) !important; color: var(--tridactyl-status-fg) !important; border: var(--tridactyl-status-border) !important; }
    }
    @-moz-document url-prefix("moz-extension://f9eff719-c9ce-4ccb-9625-be5b8f1aec81/") {
      :root {
        --in-content-page-background: #${p.background.base} !important;
        --in-content-page-color: #${p.foreground.base} !important;
        --in-content-box-background: #${p.background.base} !important;
        --in-content-box-background-hover: #${p.surface.base} !important;
        --in-content-box-background-active: #${p.surface.variant} !important;
        --in-content-text-color: #${p.foreground.base} !important;
        --in-content-selected-text: #${p.background.base} !important;
        --in-content-item-selected: #${p.accent.base} !important;
        --browser-bg: #${p.background.base} !important;
        --browser-text: #${p.foreground.base} !important;
        --tab-surface: #${p.background.base} !important;
        --tab-text: #${p.foreground.base} !important;
        --tab-surface-active: #${p.surface.base} !important;
        --tab-text-active: #${p.foreground.variant} !important;
        --tab-highlighted-base: #${p.accent.base} !important;
        --sidebar-background-color: #${p.background.base} !important;
      }
      html, body, #tabbar, #tabbar-container, #normal-tabs-container, .virtual-scroll-container {
        background: #${p.background.base} !important;
        color: #${p.foreground.base} !important;
      }
      tab-item, tab-item-substance {
        background: transparent !important;
        --tab-surface: #${p.background.base} !important;
        --tab-text: #${p.foreground.base} !important;
      }
      tab-item.active, tab-item[data-active="true"] {
        --tab-surface: #${p.surface.base} !important;
        --tab-text: #${p.foreground.variant} !important;
      }
      tab-item:hover { --tab-surface: #${p.surface.variant} !important; }
      tab-item.active tab-item-substance, tab-item[data-active="true"] tab-item-substance {
        background: #${p.surface.base} !important;
        color: #${p.foreground.variant} !important;
      }
      .newtab-button, #tabbar .newtab-button-box { background: #${p.background.base} !important; color: #${p.foreground.base} !important; }
      .newtab-button:hover { background: #${p.surface.base} !important; }
    }
  '';
  tridactylCss = ''
    :root {
      --tridactyl-fg: #${p.foreground.base};
      --tridactyl-bg: #${p.background.base};
      --tridactyl-url-fg: #${p.accent.base};
      --tridactyl-url-bg: #${p.background.base};
      --tridactyl-highlight-box-bg: #${p.surface.base};
      --tridactyl-highlight-box-fg: #${p.foreground.variant};
      --tridactyl-of-fg: #${p.foreground.variant};
      --tridactyl-of-bg: #${p.surface.variant};
      --tridactyl-cmdl-fg: #${p.foreground.variant};
      --tridactyl-cmdl-bg: #${p.background.variant};
      --tridactyl-cmdl-font-family: monospace;
      --tridactyl-cmdl-font-size: calc(12pt * 0.75);
      --tridactyl-cmdl-line-height: 1.5;
      --tridactyl-cmplt-bg: #${p.background.base};
      --tridactyl-cmplt-fg: #${p.foreground.base};
      --tridactyl-cmplt-font-family: monospace;
      --tridactyl-cmplt-font-size: calc(12pt * 9/12);
      --tridactyl-cmplt-option-height: 1.4em;
      --tridactyl-cmplt-border-top: 1px solid #${p.surface.base};
      --tridactyl-status-fg: #${p.foreground.base};
      --tridactyl-status-bg: #${p.background.base};
      --tridactyl-status-border: 1px solid #${p.surface.base};
      --tridactyl-status-border-radius: 2px;
      --tridactyl-status-font-family: monospace;
      --tridactyl-status-font-size: calc(12pt * 0.75);
      --tridactyl-hint-fg: #${p.background.base};
      --tridactyl-hint-bg: #${p.accent.base};
      --tridactyl-hint-outline: 1px solid #${p.accent.variant};
      --tridactyl-hint-active-fg: #${p.background.base};
      --tridactyl-hint-active-bg: #${p.accent.variant};
      --tridactyl-hint-active-outline: 1px solid #${p.foreground.variant};
      --tridactyl-hintspan-fg: #${p.background.base} !important;
      --tridactyl-hintspan-bg: #${p.accent.base} !important;
      --tridactyl-hintspan-font-family: sans-serif;
      --tridactyl-hintspan-font-size: calc(12pt * 0.75);
      --tridactyl-hintspan-font-weight: bold;
      --tridactyl-hintspan-border-color: #${p.accent.variant};
      --tridactyl-hintspan-border-width: 0px;
      --tridactyl-hintspan-border-style: solid;
      --tridactyl-scrollbar-color: #${p.surface.base} #${p.background.base};
      --tridactyl-photon-colours-accent-1: #${p.accent.base};
      --tridactyl-photon-colours-accent-2: #${p.accent.variant};
      --tridactyl-photon-colours-accent-3: #${p.accent.variant};
      --tridactyl-photon-colours-in-content-page-background: #${p.background.base};
      --tridactyl-photon-colours-in-content-page-color: #${p.foreground.base};
      --tridactyl-photon-colours-in-content-box-background: #${p.surface.base};
      --tridactyl-photon-colours-in-content-link-color: #${p.accent.base};
      --tridactyl-photon-colours-in-content-text-color: #${p.foreground.variant};
      --tridactyl-photon-colours-cm-background: #${p.background.variant};
      --tridactyl-photon-colours-cm-selection: #${p.surface.base};
    }
    #command-line-holder { order: 1; border: 1px solid #${p.surface.base} !important; background: var(--tridactyl-cmdl-bg) !important; }
    #tridactyl-input { color: var(--tridactyl-cmdl-fg) !important; background: var(--tridactyl-cmdl-bg) !important; }
    #completions { --option-height: var(--tridactyl-cmplt-option-height); color: var(--tridactyl-cmplt-fg) !important; background: var(--tridactyl-cmplt-bg) !important; border-top: var(--tridactyl-cmplt-border-top) !important; }
    #completions .focused { background: #${p.accent.base} !important; color: #${p.background.base} !important; }
    #completions .focused .url { background: #${p.accent.base} !important; color: #${p.background.base} !important; }
    .TridactylStatusIndicator { background: var(--tridactyl-status-bg) !important; color: var(--tridactyl-status-fg) !important; border: var(--tridactyl-status-border) !important; }
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
    colourscheme --url file://${config.home.homeDirectory}/.config/tridactyl/themes/angst.css angst
  '';
in
{
  config = lib.mkIf cfg.enable {
    programs.firefox = {
      enable = true;
      package = pkgs.firefox.override {
        extraPrefs = ''
          try {
            const SVC = (() => {
              try { return ChromeUtils.importESModule("resource://gre/modules/Services.sys.mjs").Services; } catch(e) {}
              try { return ChromeUtils.import("resource://gre/modules/Services.jsm").Services; } catch(e) {}
              try { return Services; } catch(e) {}
              return null;
            })();
            if (SVC) {
              SVC.obs.addObserver((subject) => {
                try {
                  subject.addEventListener("DOMContentLoaded", () => {
                    try {
                      let doc = subject.document;
                      if (!doc || doc.location.href !== "chrome://browser/content/browser.xhtml") return;
                      ["key_gotoHistory", "focusURLBar"].forEach(id => {
                        let el = doc.getElementById(id);
                        if (el && el.parentNode) el.parentNode.removeChild(el);
                      });
                    } catch(e) {}
                  }, {once:true});
                } catch(e) {}
              }, "chrome-document-global-created");
            }
          } catch(e) {}
        '';
      };
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
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/tree-style-tab/latest.xpi";
          };
          "tridactyl.vim@cmcaine.co.uk" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/tridactyl-vim/latest.xpi";
          };
          "addon@darkreader.org" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
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
          "browser.theme.toolbar-theme" = toolbarThemeVal;
          "browser.theme.content-theme" = contentThemeVal;
          "browser.in-content.dark-mode" = isDark;
          "layout.css.prefers-color-scheme.content-override" = contentOverrideVal;
          "ui.systemUsesDarkTheme" = systemDarkVal;
          "extensions.autoDisableScopes" = 0;
        };
        inherit userChrome;
        inherit userContent;
      };
    };
    home.file.".mozilla/firefox/default/tridactylrc".text = tridactylrc;
    home.file.".mozilla/firefox/default/tridactyl/themes/angst.css".text = tridactylCss;
    xdg.configFile."tridactyl/themes/angst.css".text = tridactylCss;
  };
}
