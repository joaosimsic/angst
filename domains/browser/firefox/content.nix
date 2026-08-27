{ theme }:
let
  mkHexVars = vars:
    builtins.concatStringsSep "\n" (map (v: "    --${v.name}: ${v.value} !important;") vars);

  aboutVars = [
    { name = "background-color-canvas"; value = theme.bg; }
    { name = "background-color-content"; value = theme.bg; }
    { name = "card-background-color"; value = theme.bgVariant; }
    { name = "card-text-color"; value = theme.fg; }
    { name = "card-border-color"; value = "transparent"; }
    { name = "panel-background-color"; value = theme.bgVariant; }
    { name = "panel-text-color"; value = theme.fg; }
    { name = "panel-border-color"; value = "transparent"; }
    { name = "in-content-page-background"; value = theme.bg; }
    { name = "in-content-page-color"; value = theme.fg; }
    { name = "in-content-text-color"; value = theme.fg; }
    { name = "in-content-box-background"; value = theme.hoverBgHex; }
    { name = "in-content-box-text-color"; value = theme.fg; }
    { name = "in-content-box-border-color"; value = "transparent"; }
    { name = "in-content-border-color"; value = "transparent"; }
    { name = "in-content-item-hover"; value = theme.hoverBgHex; }
    { name = "in-content-item-hover-text"; value = theme.fg; }
    { name = "in-content-item-selected"; value = theme.activeBgHex; }
    { name = "in-content-item-selected-text"; value = theme.fg; }
    { name = "in-content-primary-button-background"; value = theme.accent; }
    { name = "in-content-primary-button-text-color"; value = theme.bg; }
    { name = "in-content-primary-button-background-hover"; value = theme.accentVariant; }
    { name = "color-accent-primary"; value = theme.accent; }
    { name = "color-accent-primary-hover"; value = theme.accentVariant; }
    { name = "button-background-color"; value = theme.bgVariant; }
    { name = "button-background-color-hover"; value = theme.hoverBgHex; }
    { name = "button-background-color-active"; value = theme.activeBgHex; }
    { name = "button-text-color"; value = theme.fg; }
    { name = "button-text-color-hover"; value = theme.fg; }
    { name = "button-text-color-active"; value = theme.fg; }
    { name = "input-background-color"; value = theme.bgVariant; }
    { name = "input-color"; value = theme.fg; }
    { name = "input-border-color"; value = "transparent"; }
    { name = "newtab-background-color"; value = theme.bg; }
    { name = "newtab-background-color-secondary"; value = theme.bgVariant; }
    { name = "newtab-background-card"; value = "color-mix(in srgb, ${theme.bgVariant} 85%, transparent)"; }
    { name = "newtab-text-primary-color"; value = theme.fg; }
    { name = "newtab-text-secondary-color"; value = theme.fgVariant; }
    { name = "content-search-handoff-ui-background-color"; value = theme.bgVariant; }
    { name = "content-search-handoff-ui-color"; value = theme.fg; }
  ];

  newtabVars = [
    { name = "background-color-canvas"; value = theme.bg; }
    { name = "card-background-color"; value = theme.bgVariant; }
    { name = "panel-background-color"; value = theme.bgVariant; }
    { name = "panel-text-color"; value = theme.fg; }
    { name = "newtab-background-color"; value = theme.bg; }
    { name = "newtab-background-color-secondary"; value = theme.bgVariant; }
    { name = "newtab-background-card"; value = "color-mix(in srgb, ${theme.bgVariant} 85%, transparent)"; }
    { name = "newtab-text-primary-color"; value = theme.fg; }
    { name = "newtab-text-secondary-color"; value = theme.fgVariant; }
    { name = "newtab-element-hover-color"; value = theme.hoverBgHex; }
    { name = "newtab-element-active-color"; value = theme.activeBgHex; }
    { name = "newtab-element-secondary-color"; value = theme.hoverBgHex; }
    { name = "newtab-element-secondary-hover-color"; value = theme.activeBgHex; }
    { name = "newtab-element-secondary-active-color"; value = theme.activeBgHex; }
    { name = "content-search-handoff-ui-background-color"; value = theme.bgVariant; }
    { name = "content-search-handoff-ui-color"; value = theme.fg; }
    { name = "content-search-handoff-ui-fill"; value = theme.fgVariant; }
    { name = "content-search-handoff-ui-caret-color"; value = theme.fg; }
    { name = "content-search-handoff-ui-engine-icon"; value = theme.fg; }
    { name = "newtab-primary-action-background"; value = theme.accent; }
    { name = "newtab-primary-action-background-dimmed"; value = "color-mix(in srgb, ${theme.accent} 25%, transparent)"; }
    { name = "newtab-primary-element-text-color"; value = theme.bg; }
    { name = "newtab-wordmark-color"; value = theme.fg; }
    { name = "newtab-overlay-color"; value = "color-mix(in srgb, ${theme.bg} 85%, transparent)"; }
    { name = "newtab-button-background"; value = theme.bgVariant; }
    { name = "newtab-button-hover-background"; value = theme.hoverBgHex; }
    { name = "newtab-button-active-background"; value = theme.activeBgHex; }
    { name = "newtab-button-text"; value = theme.fg; }
    { name = "newtab-border-color"; value = "transparent"; }
  ];

  tridactylContentVars = [
    { name = "tridactyl-fg"; value = theme.fg; }
    { name = "tridactyl-bg"; value = theme.bg; }
    { name = "tridactyl-url-fg"; value = theme.accent; }
    { name = "tridactyl-url-bg"; value = theme.bg; }
    { name = "tridactyl-highlight-box-bg"; value = theme.surface; }
    { name = "tridactyl-highlight-box-fg"; value = theme.fgVariant; }
    { name = "tridactyl-of-fg"; value = theme.fgVariant; }
    { name = "tridactyl-of-bg"; value = theme.surfaceVariant; }
    { name = "tridactyl-cmdl-fg"; value = theme.fgVariant; }
    { name = "tridactyl-cmdl-bg"; value = theme.bgVariant; }
    { name = "tridactyl-cmplt-bg"; value = theme.bg; }
    { name = "tridactyl-cmplt-fg"; value = theme.fg; }
    { name = "tridactyl-cmplt-border-top"; value = "none"; }
    { name = "tridactyl-status-fg"; value = theme.fg; }
    { name = "tridactyl-status-bg"; value = theme.bg; }
    { name = "tridactyl-status-border"; value = "none"; }
    { name = "tridactyl-hint-fg"; value = theme.bg; }
    { name = "tridactyl-hint-bg"; value = theme.accent; }
    { name = "tridactyl-hint-outline"; value = "none"; }
    { name = "tridactyl-hint-active-fg"; value = theme.bg; }
    { name = "tridactyl-hint-active-bg"; value = theme.accentVariant; }
    { name = "tridactyl-hintspan-fg"; value = theme.bg; }
    { name = "tridactyl-hintspan-bg"; value = theme.accent; }
    { name = "tridactyl-scrollbar-color"; value = "${theme.surface} ${theme.bg}"; }
    { name = "tridactyl-photon-colours-accent-1"; value = theme.accent; }
    { name = "tridactyl-photon-colours-accent-2"; value = theme.accentVariant; }
    { name = "tridactyl-photon-colours-in-content-page-background"; value = theme.bg; }
    { name = "tridactyl-photon-colours-in-content-page-color"; value = theme.fg; }
    { name = "tridactyl-photon-colours-cm-background"; value = theme.bgVariant; }
    { name = "tridactyl-photon-colours-cm-selection"; value = theme.surface; }
  ];

  tstVars = [
    { name = "in-content-page-background"; value = theme.bg; }
    { name = "in-content-page-color"; value = theme.fg; }
    { name = "in-content-box-background"; value = theme.bg; }
    { name = "in-content-box-background-hover"; value = theme.hoverBgHex; }
    { name = "in-content-box-background-active"; value = theme.activeBgHex; }
    { name = "in-content-text-color"; value = theme.fg; }
    { name = "in-content-selected-text"; value = theme.bg; }
    { name = "in-content-item-selected"; value = theme.accent; }
    { name = "browser-bg"; value = theme.bg; }
    { name = "browser-text"; value = theme.fg; }
    { name = "tab-surface"; value = theme.bg; }
    { name = "tab-text"; value = theme.fg; }
    { name = "tab-surface-active"; value = theme.surface; }
    { name = "tab-text-active"; value = theme.fgVariant; }
    { name = "tab-highlighted-base"; value = theme.accent; }
    { name = "sidebar-background-color"; value = theme.bg; }
  ];

  sideberyExtId = "f9eff719-c9ce-4ccb-9625-be5b8f1aec81";

  aboutBlock = ''
    @-moz-document url-prefix("about:") {
      :root {
    ${mkHexVars aboutVars}
      }
      html {
        color-scheme: ${theme.colorScheme} !important;
      }
      body {
        background-color: ${theme.bg} !important;
        color: ${theme.fg} !important;
      }
      a { color: ${theme.accent} !important; }
    }'';

  newtabBlock = ''
    @-moz-document url("about:blank"), url("about:home"), url("about:newtab") {
      :root {
    ${mkHexVars newtabVars}
      }
      body {
        background-color: ${theme.bg} !important;
        color: ${theme.fg} !important;
      }
      a { color: ${theme.accent} !important; }
      .search-handoff-button, .search-wrapper .search-handoff-button, .contentSearchHeader, .search-inner-wrapper {
        background-color: var(--content-search-handoff-ui-background-color) !important;
        color: var(--content-search-handoff-ui-color) !important;
        border-color: transparent !important;
      }
      .search-handoff-button .fake-textbox, .search-handoff-button .fake-caret {
        color: var(--content-search-handoff-ui-color) !important;
      }
    }'';

  tridactylBlock = ''
    @-moz-document url-prefix("moz-extension://") {
      :root {
    ${mkHexVars tridactylContentVars}
      }
      #command-line-holder { border: none !important; background: var(--tridactyl-cmdl-bg) !important; }
      #tridactyl-input { color: var(--tridactyl-cmdl-fg) !important; background: var(--tridactyl-cmdl-bg) !important; }
      #completions { color: var(--tridactyl-cmplt-fg) !important; background: var(--tridactyl-cmplt-bg) !important; border: none !important; }
      #completions .focused, #completions .focused .url { background: ${theme.accent} !important; color: ${theme.bg} !important; }
      .TridactylStatusIndicator { background: var(--tridactyl-status-bg) !important; color: var(--tridactyl-status-fg) !important; border: none !important; }
    }'';

  tstBlock = ''
    @-moz-document url-prefix("moz-extension://${sideberyExtId}/") {
      :root {
    ${mkHexVars tstVars}
      }
      html, body, #tabbar, #tabbar-container, #normal-tabs-container, .virtual-scroll-container {
        background: ${theme.bg} !important;
        color: ${theme.fg} !important;
      }
      tab-item, tab-item-substance {
        background: transparent !important;
        --tab-surface: ${theme.bg} !important;
        --tab-text: ${theme.fg} !important;
      }
      tab-item.active, tab-item[data-active="true"] {
        --tab-surface: ${theme.surface} !important;
        --tab-text: ${theme.fgVariant} !important;
      }
      tab-item:hover { --tab-surface: ${theme.hoverBgHex} !important; }
      tab-item.active tab-item-substance, tab-item[data-active="true"] tab-item-substance {
        background: ${theme.surface} !important;
        color: ${theme.fgVariant} !important;
      }
      .newtab-button, #tabbar .newtab-button-box { background: ${theme.bg} !important; color: ${theme.fg} !important; }
      .newtab-button:hover { background: ${theme.hoverBgHex} !important; }
    }'';
in
''
${aboutBlock}
${newtabBlock}
${tridactylBlock}
${tstBlock}
''
