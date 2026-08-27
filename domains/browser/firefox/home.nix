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
      --toolbar-color: var(--angst-fg) !important;
      --toolbarbutton-icon-fill: var(--angst-fg) !important;
      --toolbarbutton-hover-background: var(--angst-surface) !important;
      --toolbarbutton-active-background: var(--angst-surface-variant) !important;
      --lwt-toolbarbutton-icon-fill: var(--angst-fg) !important;
      --lwt-toolbarbutton-hover-background: var(--angst-surface) !important;
      --lwt-toolbarbutton-active-background: var(--angst-surface-variant) !important;
      --arrowpanel-background: var(--angst-bg-variant) !important;
      --arrowpanel-color: var(--angst-fg) !important;
      --arrowpanel-border-color: transparent !important;
      --arrowpanel-dimmed: var(--angst-surface) !important;
      --arrowpanel-dimmed-further: var(--angst-surface-variant) !important;
      --panel-background: var(--angst-bg-variant) !important;
      --panel-color: var(--angst-fg) !important;
      --panel-border-color: transparent !important;
      --panel-item-hover-bgcolor: var(--angst-surface) !important;
      --panel-item-active-bgcolor: var(--angst-accent) !important;
      --panel-item-active-color: var(--angst-bg) !important;
      --panel-separator-color: transparent !important;
      --urlbarView-result-color: var(--angst-fg) !important;
      --urlbarView-highlight-background: var(--angst-accent) !important;
      --urlbarView-highlight-color: var(--angst-bg) !important;
      --urlbarView-hover-background: var(--angst-surface) !important;
      --urlbarView-background-color: var(--angst-bg) !important;
      --urlbarView-border-color: transparent !important;
      --urlbarView-separator-color: transparent !important;
      --urlbar-box-bgcolor: transparent !important;
      --urlbar-box-background-color: transparent !important;
      --urlbar-box-text-color: var(--angst-fg) !important;
      --urlbar-box-hover-bgcolor: transparent !important;
      --urlbar-box-hover-background-color: transparent !important;
      --urlbar-box-hover-text-color: var(--angst-fg-variant) !important;
      --urlbar-box-focus-bgcolor: transparent !important;
      --urlbar-box-focus-background-color: transparent !important;
      --urlbar-box-focus-text-color: var(--angst-fg-variant) !important;
      --urlbar-box-border-color: transparent !important;
      --toolbar-field-background-color: var(--angst-bg-variant) !important;
      --toolbar-field-color: var(--angst-fg) !important;
      --toolbar-field-border-color: transparent !important;
      --toolbar-field-focus-background-color: var(--angst-bg) !important;
      --toolbar-field-focus-color: var(--angst-fg-variant) !important;
      --toolbar-field-focus-border-color: transparent !important;
      --lwt-toolbar-field-background-color: var(--angst-bg-variant) !important;
      --lwt-toolbar-field-color: var(--angst-fg) !important;
      --lwt-toolbar-field-focus: var(--angst-bg) !important;
      --lwt-toolbar-field-focus-color: var(--angst-fg-variant) !important;
      --toolbar-field-highlight: var(--angst-accent) !important;
      --toolbar-field-highlight-text: var(--angst-bg) !important;
      --tabpanel-background-color: var(--angst-bg) !important;
      --lwt-tab-text: var(--angst-fg) !important;
      --tab-selected-bgcolor: var(--angst-accent) !important;
      --tab-selected-textcolor: var(--angst-bg) !important;
      --lwt-selected-tab-background-color: var(--angst-accent) !important;
      --chrome-content-separator-color: transparent !important;
      --sidebar-background-color: var(--angst-bg) !important;
      --sidebar-text-color: var(--angst-fg) !important;
      --sidebar-border-color: transparent !important;
      --toolbox-border-bottom-color: transparent !important;
      --titlebar-color: var(--angst-fg) !important;
      --titlebar-background-color: var(--angst-bg) !important;
      --background-color-canvas: var(--angst-bg) !important;
      --background-color-content: var(--angst-bg) !important;
      --card-background-color: var(--angst-bg-variant) !important;
      --card-text-color: var(--angst-fg) !important;
      --card-border-color: transparent !important;
      --panel-background-color: var(--angst-bg-variant) !important;
      --panel-text-color: var(--angst-fg) !important;
      --in-content-page-background: var(--angst-bg) !important;
      --in-content-page-color: var(--angst-fg) !important;
      --in-content-text-color: var(--angst-fg) !important;
      --in-content-box-background: var(--angst-surface) !important;
      --in-content-box-text-color: var(--angst-bg) !important;
      --in-content-box-border-color: transparent !important;
      --in-content-border-color: transparent !important;
      --in-content-item-hover: var(--angst-surface) !important;
      --in-content-item-hover-text: var(--angst-fg-variant) !important;
      --in-content-item-selected: var(--angst-accent) !important;
      --in-content-item-selected-text: var(--angst-bg) !important;
      --in-content-primary-button-background: var(--angst-accent) !important;
      --in-content-primary-button-text-color: var(--angst-bg) !important;
      --in-content-primary-button-background-hover: var(--angst-accent-variant) !important;
      --in-content-primary-button-background-active: var(--angst-accent-variant) !important;
      --color-accent-primary: var(--angst-accent) !important;
      --color-accent-primary-hover: var(--angst-accent-variant) !important;
      --color-accent-primary-active: var(--angst-accent-variant) !important;
      --button-background-color: var(--angst-surface) !important;
      --button-background-color-hover: var(--angst-surface-variant) !important;
      --button-background-color-active: var(--angst-accent) !important;
      --button-text-color: var(--angst-fg) !important;
      --button-text-color-hover: var(--angst-fg-variant) !important;
      --button-text-color-active: var(--angst-bg) !important;
      --input-background-color: var(--angst-bg-variant) !important;
      --input-color: var(--angst-fg) !important;
      --input-border-color: transparent !important;
    }
    #navigator-toolbox {
      background-color: var(--angst-bg) !important;
      color: var(--angst-fg) !important;
      border: none !important;
    }
    #TabsToolbar {
      visibility: collapse !important;
    }
    #PersonalToolbar {
      background: var(--angst-bg) !important;
      color: var(--angst-fg) !important;
      border: none !important;
    }
    #nav-bar {
      background: var(--angst-bg) !important;
      box-shadow: none !important;
      border: none !important;
    }
    #urlbar, #urlbar * {
      --toolbar-field-background-color: var(--angst-bg-variant) !important;
      --toolbar-field-focus-background-color: var(--angst-bg) !important;
    }
    #urlbar-background, #searchbar {
      background-color: var(--angst-bg-variant) !important;
      background: var(--angst-bg-variant) !important;
      border-color: transparent !important;
      box-shadow: none !important;
    }
    #urlbar[focused] > #urlbar-background,
    #urlbar[open] > #urlbar-background,
    #urlbar[breakout][breakout-extend] > #urlbar-background,
    #urlbar[breakout][breakout-extend][open] > #urlbar-background,
    .urlbar-background, #searchbar:focus-within {
      background-color: var(--angst-bg) !important;
      background: var(--angst-bg) !important;
      border-color: transparent !important;
      box-shadow: none !important;
    }
    #urlbar[breakout][breakout-extend] { background: transparent !important; }
    #urlbar-input, #urlbar-input::placeholder, .urlbar-input, #searchbar input {
      color: var(--angst-fg) !important;
    }
    #urlbarView, .urlbarView-body-inner, #urlbar-results {
      background: var(--angst-bg) !important;
      background-color: var(--angst-bg) !important;
      color: var(--angst-fg) !important;
      border: none !important;
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
    #sidebar-box, #sidebar {
      background: var(--angst-bg) !important;
      border: none !important;
    }
    panel, menupopup, .panel-arrowcontent {
      --panel-background: var(--angst-bg-variant) !important;
      --panel-color: var(--angst-fg) !important;
      --panel-border-color: transparent !important;
      background: var(--angst-bg-variant) !important;
      color: var(--angst-fg) !important;
      border: none !important;
    }
    menupopup {
      --panel-background: var(--angst-bg-variant) !important;
      --panel-color: var(--angst-fg) !important;
      --panel-border-color: transparent !important;
      border: none !important;
    }
    #appMenu-popup, #unified-extensions-panel, #downloadsPanel, #identity-popup, #permission-popup, #protections-popup {
      --panel-background: var(--angst-bg-variant) !important;
      --panel-color: var(--angst-fg) !important;
    }
    #findbar {
      background: var(--angst-bg-variant) !important;
      border-top: none !important;
      border-color: transparent !important;
    }
    html, body, #main-window, #browser, #appcontent, #tabbrowser-tabpanels {
      background: var(--tabpanel-background-color) !important;
    }
  '';
  userContent = ''
    @-moz-document url-prefix("about:") {
      :root {
        --background-color-canvas: #${p.background.base} !important;
        --background-color-content: #${p.background.base} !important;
        --card-background-color: #${p.background.variant} !important;
        --card-text-color: #${p.foreground.base} !important;
        --card-border-color: transparent !important;
        --panel-background-color: #${p.background.variant} !important;
        --panel-text-color: #${p.foreground.base} !important;
        --panel-border-color: transparent !important;
        --in-content-page-background: #${p.background.base} !important;
        --in-content-page-color: #${p.foreground.base} !important;
        --in-content-text-color: #${p.foreground.base} !important;
        --in-content-box-background: #${p.surface.base} !important;
        --in-content-box-text-color: #${p.background.base} !important;
        --in-content-box-border-color: transparent !important;
        --in-content-border-color: transparent !important;
        --in-content-item-hover: #${p.surface.base} !important;
        --in-content-item-hover-text: #${p.foreground.variant} !important;
        --in-content-item-selected: #${p.accent.base} !important;
        --in-content-item-selected-text: #${p.background.base} !important;
        --in-content-primary-button-background: #${p.accent.base} !important;
        --in-content-primary-button-text-color: #${p.background.base} !important;
        --in-content-primary-button-background-hover: #${p.accent.variant} !important;
        --color-accent-primary: #${p.accent.base} !important;
        --color-accent-primary-hover: #${p.accent.variant} !important;
        --button-background-color: #${p.surface.base} !important;
        --button-text-color: #${p.foreground.base} !important;
        --input-background-color: #${p.background.variant} !important;
        --input-color: #${p.foreground.base} !important;
        --input-border-color: transparent !important;
      }
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
      :root {
        --background-color-canvas: #${p.background.base} !important;
        --card-background-color: #${p.background.variant} !important;
        --panel-background-color: #${p.background.variant} !important;
        --panel-text-color: #${p.foreground.base} !important;
      }
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
        --tridactyl-cmplt-border-top: none !important;
        --tridactyl-status-fg: #${p.foreground.base} !important;
        --tridactyl-status-bg: #${p.background.base} !important;
        --tridactyl-status-border: none !important;
        --tridactyl-hint-fg: #${p.background.base} !important;
        --tridactyl-hint-bg: #${p.accent.base} !important;
        --tridactyl-hint-outline: none !important;
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
      #command-line-holder { border: none !important; background: var(--tridactyl-cmdl-bg) !important; }
      #tridactyl-input { color: var(--tridactyl-cmdl-fg) !important; background: var(--tridactyl-cmdl-bg) !important; }
      #completions { color: var(--tridactyl-cmplt-fg) !important; background: var(--tridactyl-cmplt-bg) !important; border: none !important; }
      #completions .focused, #completions .focused .url { background: #${p.accent.base} !important; color: #${p.background.base} !important; }
      .TridactylStatusIndicator { background: var(--tridactyl-status-bg) !important; color: var(--tridactyl-status-fg) !important; border: none !important; }
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
      --tridactyl-cmplt-border-top: none;
      --tridactyl-status-fg: #${p.foreground.base};
      --tridactyl-status-bg: #${p.background.base};
      --tridactyl-status-border: none;
      --tridactyl-status-border-radius: 2px;
      --tridactyl-status-font-family: monospace;
      --tridactyl-status-font-size: calc(12pt * 0.75);
      --tridactyl-hint-fg: #${p.background.base};
      --tridactyl-hint-bg: #${p.accent.base};
      --tridactyl-hint-outline: none;
      --tridactyl-hint-active-fg: #${p.background.base};
      --tridactyl-hint-active-bg: #${p.accent.variant};
      --tridactyl-hint-active-outline: none;
      --tridactyl-hintspan-fg: #${p.background.base} !important;
      --tridactyl-hintspan-bg: #${p.accent.base} !important;
      --tridactyl-hintspan-font-family: sans-serif;
      --tridactyl-hintspan-font-size: calc(12pt * 0.75);
      --tridactyl-hintspan-font-weight: bold;
      --tridactyl-hintspan-border-color: transparent;
      --tridactyl-hintspan-border-width: 0px;
      --tridactyl-hintspan-border-style: none;
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
    #command-line-holder { order: 1; border: none !important; background: var(--tridactyl-cmdl-bg) !important; }
    #tridactyl-input { color: var(--tridactyl-cmdl-fg) !important; background: var(--tridactyl-cmdl-bg) !important; }
    #completions { --option-height: var(--tridactyl-cmplt-option-height); color: var(--tridactyl-cmplt-fg) !important; background: var(--tridactyl-cmplt-bg) !important; border: none !important; }
    #completions .focused { background: #${p.accent.base} !important; color: #${p.background.base} !important; }
    #completions .focused .url { background: #${p.accent.base} !important; color: #${p.background.base} !important; }
    .TridactylStatusIndicator { background: var(--tridactyl-status-bg) !important; color: var(--tridactyl-status-fg) !important; border: none !important; }
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
        DisplayBookmarksToolbar = "always";
        OfferToSaveLogins = false;
        ExtensionSettings = {
          "treestyletab@piro.sakura.ne.jp" = {
            installation_mode = "blocked";
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
          "browser.toolbars.bookmarks.visibility" = "always";
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "browser.uidensity" = 0;
          "browser.theme.toolbar-theme" = toolbarThemeVal;
          "browser.theme.content-theme" = contentThemeVal;
          "browser.in-content.dark-mode" = isDark;
          "layout.css.prefers-color-scheme.content-override" = contentOverrideVal;
          "ui.systemUsesDarkTheme" = systemDarkVal;
          "extensions.autoDisableScopes" = 0;
          "sidebar.revamp" = true;
          "sidebar.verticalTabs" = true;
          "sidebar.visibility" = "always-show";
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
