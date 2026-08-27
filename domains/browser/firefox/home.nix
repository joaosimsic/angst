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
  # Centralized palette - all theme colors initialized here, referenced via interpolation
  bg = "#${p.background.base}";
  bgVariant = "#${p.background.variant}";
  surface = "#${p.surface.base}";
  surfaceVariant = "#${p.surface.variant}";
  fg = "#${p.foreground.base}";
  fgVariant = "#${p.foreground.variant}";
  accent = "#${p.accent.base}";
  accentVariant = "#${p.accent.variant}";
  dim = "#${p.dim}";
  # Centralized derived UI states - unified hover/active for all classes
  # Uses subtle fg mix over bg so fg base text (used by most elements) keeps contrast
  hoverBg = "color-mix(in srgb, var(--angst-fg) 10%, var(--angst-bg))";
  activeBg = "color-mix(in srgb, var(--angst-fg) 16%, var(--angst-bg))";
  hoverBgHex = "color-mix(in srgb, ${fg} 10%, ${bg})";
  activeBgHex = "color-mix(in srgb, ${fg} 16%, ${bg})";
  userChrome = ''
    :root {
      color-scheme: ${colorScheme} !important;
      --angst-bg: ${bg};
      --angst-bg-variant: ${bgVariant};
      --angst-surface: ${surface};
      --angst-surface-variant: ${surfaceVariant};
      --angst-fg: ${fg};
      --angst-fg-variant: ${fgVariant};
      --angst-accent: ${accent};
      --angst-accent-variant: ${accentVariant};
      --angst-dim: ${dim};
      --angst-hover-bg: ${hoverBg} !important;
      --angst-active-bg: ${activeBg} !important;
      --lwt-accent-color: var(--angst-bg) !important;
      --lwt-text-color: var(--angst-fg) !important;
      --toolbar-bgcolor: var(--angst-bg) !important;
      --toolbar-color: var(--angst-fg) !important;
      --toolbarbutton-icon-fill: var(--angst-fg) !important;
      --toolbarbutton-hover-background: var(--angst-hover-bg) !important;
      --toolbarbutton-active-background: var(--angst-active-bg) !important;
      --lwt-toolbarbutton-icon-fill: var(--angst-fg) !important;
      --lwt-toolbarbutton-hover-background: var(--angst-hover-bg) !important;
      --lwt-toolbarbutton-active-background: var(--angst-active-bg) !important;
      --arrowpanel-background: var(--angst-bg-variant) !important;
      --arrowpanel-color: var(--angst-fg) !important;
      --arrowpanel-border-color: transparent !important;
      --arrowpanel-dimmed: var(--angst-hover-bg) !important;
      --arrowpanel-dimmed-further: var(--angst-active-bg) !important;
      --panel-background: var(--angst-bg-variant) !important;
      --panel-color: var(--angst-fg) !important;
      --panel-border-color: transparent !important;
      --panel-item-hover-bgcolor: var(--angst-hover-bg) !important;
      --panel-item-active-bgcolor: var(--angst-active-bg) !important;
      --panel-item-active-color: var(--angst-fg) !important;
      --panel-separator-color: transparent !important;
      --urlbarView-result-color: var(--angst-fg) !important;
      --urlbarView-highlight-background: var(--angst-active-bg) !important;
      --urlbarView-highlight-color: var(--angst-fg) !important;
      --urlbarView-hover-background: var(--angst-hover-bg) !important;
      --urlbarView-background-color: var(--angst-bg) !important;
      --urlbarView-border-color: transparent !important;
      --urlbarView-separator-color: transparent !important;
      --urlbar-box-bgcolor: transparent !important;
      --urlbar-box-background-color: transparent !important;
      --urlbar-box-text-color: var(--angst-fg) !important;
      --urlbar-box-hover-bgcolor: var(--angst-hover-bg) !important;
      --urlbar-box-hover-background-color: var(--angst-hover-bg) !important;
      --urlbar-box-hover-text-color: var(--angst-fg) !important;
      --urlbar-box-focus-bgcolor: var(--angst-active-bg) !important;
      --urlbar-box-focus-background-color: var(--angst-active-bg) !important;
      --urlbar-box-focus-text-color: var(--angst-fg) !important;
      --urlbar-box-border-color: transparent !important;
      --toolbar-field-background-color: var(--angst-bg-variant) !important;
      --toolbar-field-color: var(--angst-fg) !important;
      --toolbar-field-border-color: transparent !important;
      --toolbar-field-focus-background-color: var(--angst-bg) !important;
      --toolbar-field-focus-color: var(--angst-fg) !important;
      --toolbar-field-focus-border-color: transparent !important;
      --lwt-toolbar-field-background-color: var(--angst-bg-variant) !important;
      --lwt-toolbar-field-color: var(--angst-fg) !important;
      --lwt-toolbar-field-focus: var(--angst-bg) !important;
      --lwt-toolbar-field-focus-color: var(--angst-fg) !important;
      --toolbar-field-highlight: var(--angst-accent) !important;
      --toolbar-field-highlight-text: var(--angst-bg) !important;
      --tabpanel-background-color: var(--angst-bg) !important;
      --lwt-tab-text: var(--angst-fg) !important;
      --tab-selected-bgcolor: var(--angst-active-bg) !important;
      --tab-selected-textcolor: var(--angst-fg) !important;
      --lwt-selected-tab-background-color: var(--angst-active-bg) !important;
      --tab-background-color: var(--angst-bg) !important;
      --tab-background-color-selected: var(--angst-active-bg) !important;
      --tab-background-color-hover: var(--angst-hover-bg) !important;
      --tab-text-color: var(--angst-fg) !important;
      --tab-text-color-selected: var(--angst-fg) !important;
      --tab-text-color-hover: var(--angst-fg) !important;
      --tab-border-color: transparent !important;
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
      --in-content-box-background: var(--angst-active-bg) !important;
      --in-content-box-text-color: var(--angst-fg) !important;
      --in-content-box-border-color: transparent !important;
      --in-content-border-color: transparent !important;
      --in-content-item-hover: var(--angst-hover-bg) !important;
      --in-content-item-hover-text: var(--angst-fg) !important;
      --in-content-item-selected: var(--angst-active-bg) !important;
      --in-content-item-selected-text: var(--angst-fg) !important;
      --in-content-primary-button-background: var(--angst-accent) !important;
      --in-content-primary-button-text-color: var(--angst-bg) !important;
      --in-content-primary-button-background-hover: var(--angst-accent-variant) !important;
      --in-content-primary-button-background-active: var(--angst-accent-variant) !important;
      --color-accent-primary: var(--angst-accent) !important;
      --color-accent-primary-hover: var(--angst-accent-variant) !important;
      --color-accent-primary-active: var(--angst-accent-variant) !important;
      --button-background-color: var(--angst-bg-variant) !important;
      --button-background-color-hover: var(--angst-hover-bg) !important;
      --button-background-color-active: var(--angst-active-bg) !important;
      --button-text-color: var(--angst-fg) !important;
      --button-text-color-hover: var(--angst-fg) !important;
      --button-text-color-active: var(--angst-fg) !important;
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
        --background-color-canvas: ${bg} !important;
        --background-color-content: ${bg} !important;
        --card-background-color: ${bgVariant} !important;
        --card-text-color: ${fg} !important;
        --card-border-color: transparent !important;
        --panel-background-color: ${bgVariant} !important;
        --panel-text-color: ${fg} !important;
        --panel-border-color: transparent !important;
        --in-content-page-background: ${bg} !important;
        --in-content-page-color: ${fg} !important;
        --in-content-text-color: ${fg} !important;
        --in-content-box-background: ${hoverBgHex} !important;
        --in-content-box-text-color: ${fg} !important;
        --in-content-box-border-color: transparent !important;
        --in-content-border-color: transparent !important;
        --in-content-item-hover: ${hoverBgHex} !important;
        --in-content-item-hover-text: ${fg} !important;
        --in-content-item-selected: ${activeBgHex} !important;
        --in-content-item-selected-text: ${fg} !important;
        --in-content-primary-button-background: ${accent} !important;
        --in-content-primary-button-text-color: ${bg} !important;
        --in-content-primary-button-background-hover: ${accentVariant} !important;
        --color-accent-primary: ${accent} !important;
        --color-accent-primary-hover: ${accentVariant} !important;
        --button-background-color: ${bgVariant} !important;
        --button-background-color-hover: ${hoverBgHex} !important;
        --button-background-color-active: ${activeBgHex} !important;
        --button-text-color: ${fg} !important;
        --button-text-color-hover: ${fg} !important;
        --button-text-color-active: ${fg} !important;
        --input-background-color: ${bgVariant} !important;
        --input-color: ${fg} !important;
        --input-border-color: transparent !important;
      }
      html {
        color-scheme: ${colorScheme} !important;
      }
      body {
        background-color: ${bg} !important;
        color: ${fg} !important;
      }
      a { color: ${accent} !important; }
    }
    @-moz-document url("about:blank"), url("about:home"), url("about:newtab") {
      :root {
        --background-color-canvas: ${bg} !important;
        --card-background-color: ${bgVariant} !important;
        --panel-background-color: ${bgVariant} !important;
        --panel-text-color: ${fg} !important;
      }
      body {
        background-color: ${bg} !important;
        color: ${fg} !important;
      }
      a { color: ${accent} !important; }
    }
    @-moz-document url-prefix("moz-extension://") {
      :root {
        --tridactyl-fg: ${fg} !important;
        --tridactyl-bg: ${bg} !important;
        --tridactyl-url-fg: ${accent} !important;
        --tridactyl-url-bg: ${bg} !important;
        --tridactyl-highlight-box-bg: ${surface} !important;
        --tridactyl-highlight-box-fg: ${fgVariant} !important;
        --tridactyl-of-fg: ${fgVariant} !important;
        --tridactyl-of-bg: ${surfaceVariant} !important;
        --tridactyl-cmdl-fg: ${fgVariant} !important;
        --tridactyl-cmdl-bg: ${bgVariant} !important;
        --tridactyl-cmplt-bg: ${bg} !important;
        --tridactyl-cmplt-fg: ${fg} !important;
        --tridactyl-cmplt-border-top: none !important;
        --tridactyl-status-fg: ${fg} !important;
        --tridactyl-status-bg: ${bg} !important;
        --tridactyl-status-border: none !important;
        --tridactyl-hint-fg: ${bg} !important;
        --tridactyl-hint-bg: ${accent} !important;
        --tridactyl-hint-outline: none !important;
        --tridactyl-hint-active-fg: ${bg} !important;
        --tridactyl-hint-active-bg: ${accentVariant} !important;
        --tridactyl-hintspan-fg: ${bg} !important;
        --tridactyl-hintspan-bg: ${accent} !important;
        --tridactyl-scrollbar-color: ${surface} ${bg} !important;
        --tridactyl-photon-colours-accent-1: ${accent} !important;
        --tridactyl-photon-colours-accent-2: ${accentVariant} !important;
        --tridactyl-photon-colours-in-content-page-background: ${bg} !important;
        --tridactyl-photon-colours-in-content-page-color: ${fg} !important;
        --tridactyl-photon-colours-cm-background: ${bgVariant} !important;
        --tridactyl-photon-colours-cm-selection: ${surface} !important;
      }
      #command-line-holder { border: none !important; background: var(--tridactyl-cmdl-bg) !important; }
      #tridactyl-input { color: var(--tridactyl-cmdl-fg) !important; background: var(--tridactyl-cmdl-bg) !important; }
      #completions { color: var(--tridactyl-cmplt-fg) !important; background: var(--tridactyl-cmplt-bg) !important; border: none !important; }
      #completions .focused, #completions .focused .url { background: ${accent} !important; color: ${bg} !important; }
      .TridactylStatusIndicator { background: var(--tridactyl-status-bg) !important; color: var(--tridactyl-status-fg) !important; border: none !important; }
    }
    @-moz-document url-prefix("moz-extension://f9eff719-c9ce-4ccb-9625-be5b8f1aec81/") {
      :root {
        --in-content-page-background: ${bg} !important;
        --in-content-page-color: ${fg} !important;
        --in-content-box-background: ${bg} !important;
        --in-content-box-background-hover: ${hoverBgHex} !important;
        --in-content-box-background-active: ${activeBgHex} !important;
        --in-content-text-color: ${fg} !important;
        --in-content-selected-text: ${bg} !important;
        --in-content-item-selected: ${accent} !important;
        --browser-bg: ${bg} !important;
        --browser-text: ${fg} !important;
        --tab-surface: ${bg} !important;
        --tab-text: ${fg} !important;
        --tab-surface-active: ${surface} !important;
        --tab-text-active: ${fgVariant} !important;
        --tab-highlighted-base: ${accent} !important;
        --sidebar-background-color: ${bg} !important;
      }
      html, body, #tabbar, #tabbar-container, #normal-tabs-container, .virtual-scroll-container {
        background: ${bg} !important;
        color: ${fg} !important;
      }
      tab-item, tab-item-substance {
        background: transparent !important;
        --tab-surface: ${bg} !important;
        --tab-text: ${fg} !important;
      }
      tab-item.active, tab-item[data-active="true"] {
        --tab-surface: ${surface} !important;
        --tab-text: ${fgVariant} !important;
      }
      tab-item:hover { --tab-surface: ${hoverBgHex} !important; }
      tab-item.active tab-item-substance, tab-item[data-active="true"] tab-item-substance {
        background: ${surface} !important;
        color: ${fgVariant} !important;
      }
      .newtab-button, #tabbar .newtab-button-box { background: ${bg} !important; color: ${fg} !important; }
      .newtab-button:hover { background: ${hoverBgHex} !important; }
    }
  '';
  tridactylCss = ''
    :root {
      --tridactyl-fg: ${fg};
      --tridactyl-bg: ${bg};
      --tridactyl-url-fg: ${accent};
      --tridactyl-url-bg: ${bg};
      --tridactyl-highlight-box-bg: ${surface};
      --tridactyl-highlight-box-fg: ${fgVariant};
      --tridactyl-of-fg: ${fgVariant};
      --tridactyl-of-bg: ${surfaceVariant};
      --tridactyl-cmdl-fg: ${fgVariant};
      --tridactyl-cmdl-bg: ${bgVariant};
      --tridactyl-cmdl-font-family: monospace;
      --tridactyl-cmdl-font-size: calc(12pt * 0.75);
      --tridactyl-cmdl-line-height: 1.5;
      --tridactyl-cmplt-bg: ${bg};
      --tridactyl-cmplt-fg: ${fg};
      --tridactyl-cmplt-font-family: monospace;
      --tridactyl-cmplt-font-size: calc(12pt * 9/12);
      --tridactyl-cmplt-option-height: 1.4em;
      --tridactyl-cmplt-border-top: none;
      --tridactyl-status-fg: ${fg};
      --tridactyl-status-bg: ${bg};
      --tridactyl-status-border: none;
      --tridactyl-status-border-radius: 2px;
      --tridactyl-status-font-family: monospace;
      --tridactyl-status-font-size: calc(12pt * 0.75);
      --tridactyl-hint-fg: ${bg};
      --tridactyl-hint-bg: ${accent};
      --tridactyl-hint-outline: none;
      --tridactyl-hint-active-fg: ${bg};
      --tridactyl-hint-active-bg: ${accentVariant};
      --tridactyl-hint-active-outline: none;
      --tridactyl-hintspan-fg: ${bg} !important;
      --tridactyl-hintspan-bg: ${accent} !important;
      --tridactyl-hintspan-font-family: sans-serif;
      --tridactyl-hintspan-font-size: calc(12pt * 0.75);
      --tridactyl-hintspan-font-weight: bold;
      --tridactyl-hintspan-border-color: transparent;
      --tridactyl-hintspan-border-width: 0px;
      --tridactyl-hintspan-border-style: none;
      --tridactyl-scrollbar-color: ${surface} ${bg};
      --tridactyl-photon-colours-accent-1: ${accent};
      --tridactyl-photon-colours-accent-2: ${accentVariant};
      --tridactyl-photon-colours-accent-3: ${accentVariant};
      --tridactyl-photon-colours-in-content-page-background: ${bg};
      --tridactyl-photon-colours-in-content-page-color: ${fg};
      --tridactyl-photon-colours-in-content-box-background: ${surface};
      --tridactyl-photon-colours-in-content-link-color: ${accent};
      --tridactyl-photon-colours-in-content-text-color: ${fgVariant};
      --tridactyl-photon-colours-cm-background: ${bgVariant};
      --tridactyl-photon-colours-cm-selection: ${surface};
    }
    #command-line-holder { order: 1; border: none !important; background: var(--tridactyl-cmdl-bg) !important; }
    #tridactyl-input { color: var(--tridactyl-cmdl-fg) !important; background: var(--tridactyl-cmdl-bg) !important; }
    #completions { --option-height: var(--tridactyl-cmplt-option-height); color: var(--tridactyl-cmplt-fg) !important; background: var(--tridactyl-cmplt-bg) !important; border: none !important; }
    #completions .focused { background: ${accent} !important; color: ${bg} !important; }
    #completions .focused .url { background: ${accent} !important; color: ${bg} !important; }
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
    colours statusfg ${fg}
    colours statusbg ${bg}
    colours hintfg ${bg}
    colours hintbg ${accent}
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
