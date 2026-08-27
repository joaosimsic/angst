{ theme }:
let
  angstVars = [
    {
      name = "angst-bg";
      value = theme.bg;
      important = false;
    }
    {
      name = "angst-bg-variant";
      value = theme.bgVariant;
      important = false;
    }
    {
      name = "angst-surface";
      value = theme.surface;
      important = false;
    }
    {
      name = "angst-surface-variant";
      value = theme.surfaceVariant;
      important = false;
    }
    {
      name = "angst-fg";
      value = theme.fg;
      important = false;
    }
    {
      name = "angst-fg-variant";
      value = theme.fgVariant;
      important = false;
    }
    {
      name = "angst-accent";
      value = theme.accent;
      important = false;
    }
    {
      name = "angst-accent-variant";
      value = theme.accentVariant;
      important = false;
    }
    {
      name = "angst-dim";
      value = theme.dim;
      important = false;
    }
    {
      name = "angst-hover-bg";
      value = theme.hoverBg;
      important = true;
    }
    {
      name = "angst-active-bg";
      value = theme.activeBg;
      important = true;
    }
  ];

  chromeVars = [
    {
      name = "lwt-accent-color";
      value = "var(--angst-bg)";
    }
    {
      name = "lwt-text-color";
      value = "var(--angst-fg)";
    }
    {
      name = "toolbar-bgcolor";
      value = "var(--angst-bg)";
    }
    {
      name = "toolbar-color";
      value = "var(--angst-fg)";
    }
    {
      name = "toolbarbutton-icon-fill";
      value = "var(--angst-fg)";
    }
    {
      name = "toolbarbutton-hover-background";
      value = "var(--angst-hover-bg)";
    }
    {
      name = "toolbarbutton-active-background";
      value = "var(--angst-active-bg)";
    }
    {
      name = "lwt-toolbarbutton-icon-fill";
      value = "var(--angst-fg)";
    }
    {
      name = "lwt-toolbarbutton-hover-background";
      value = "var(--angst-hover-bg)";
    }
    {
      name = "lwt-toolbarbutton-active-background";
      value = "var(--angst-active-bg)";
    }
    {
      name = "arrowpanel-background";
      value = "var(--angst-bg-variant)";
    }
    {
      name = "arrowpanel-color";
      value = "var(--angst-fg)";
    }
    {
      name = "arrowpanel-border-color";
      value = "transparent";
    }
    {
      name = "arrowpanel-dimmed";
      value = "var(--angst-hover-bg)";
    }
    {
      name = "arrowpanel-dimmed-further";
      value = "var(--angst-active-bg)";
    }
    {
      name = "panel-background";
      value = "var(--angst-bg-variant)";
    }
    {
      name = "panel-color";
      value = "var(--angst-fg)";
    }
    {
      name = "panel-border-color";
      value = "transparent";
    }
    {
      name = "panel-item-hover-bgcolor";
      value = "var(--angst-hover-bg)";
    }
    {
      name = "panel-item-active-bgcolor";
      value = "var(--angst-active-bg)";
    }
    {
      name = "panel-item-active-color";
      value = "var(--angst-fg)";
    }
    {
      name = "panel-separator-color";
      value = "transparent";
    }
    {
      name = "urlbarView-result-color";
      value = "var(--angst-fg)";
    }
    {
      name = "urlbarView-highlight-background";
      value = "var(--angst-active-bg)";
    }
    {
      name = "urlbarView-highlight-color";
      value = "var(--angst-fg)";
    }
    {
      name = "urlbarView-hover-background";
      value = "var(--angst-hover-bg)";
    }
    {
      name = "urlbarView-background-color";
      value = "var(--angst-bg)";
    }
    {
      name = "urlbarView-border-color";
      value = "transparent";
    }
    {
      name = "urlbarView-separator-color";
      value = "transparent";
    }
    {
      name = "urlbar-box-bgcolor";
      value = "transparent";
    }
    {
      name = "urlbar-box-background-color";
      value = "transparent";
    }
    {
      name = "urlbar-box-text-color";
      value = "var(--angst-fg)";
    }
    {
      name = "urlbar-box-hover-bgcolor";
      value = "var(--angst-hover-bg)";
    }
    {
      name = "urlbar-box-hover-background-color";
      value = "var(--angst-hover-bg)";
    }
    {
      name = "urlbar-box-hover-text-color";
      value = "var(--angst-fg)";
    }
    {
      name = "urlbar-box-focus-bgcolor";
      value = "var(--angst-active-bg)";
    }
    {
      name = "urlbar-box-focus-background-color";
      value = "var(--angst-active-bg)";
    }
    {
      name = "urlbar-box-focus-text-color";
      value = "var(--angst-fg)";
    }
    {
      name = "urlbar-box-border-color";
      value = "transparent";
    }
    {
      name = "toolbar-field-background-color";
      value = "var(--angst-bg-variant)";
    }
    {
      name = "toolbar-field-color";
      value = "var(--angst-fg)";
    }
    {
      name = "toolbar-field-border-color";
      value = "transparent";
    }
    {
      name = "toolbar-field-focus-background-color";
      value = "var(--angst-bg)";
    }
    {
      name = "toolbar-field-focus-color";
      value = "var(--angst-fg)";
    }
    {
      name = "toolbar-field-focus-border-color";
      value = "transparent";
    }
    {
      name = "lwt-toolbar-field-background-color";
      value = "var(--angst-bg-variant)";
    }
    {
      name = "lwt-toolbar-field-color";
      value = "var(--angst-fg)";
    }
    {
      name = "lwt-toolbar-field-focus";
      value = "var(--angst-bg)";
    }
    {
      name = "lwt-toolbar-field-focus-color";
      value = "var(--angst-fg)";
    }
    {
      name = "toolbar-field-highlight";
      value = "var(--angst-accent)";
    }
    {
      name = "toolbar-field-highlight-text";
      value = "var(--angst-bg)";
    }
    {
      name = "tabpanel-background-color";
      value = "var(--angst-bg)";
    }
    {
      name = "lwt-tab-text";
      value = "var(--angst-fg)";
    }
    {
      name = "tab-selected-bgcolor";
      value = "var(--angst-active-bg)";
    }
    {
      name = "tab-selected-textcolor";
      value = "var(--angst-fg)";
    }
    {
      name = "lwt-selected-tab-background-color";
      value = "var(--angst-active-bg)";
    }
    {
      name = "tab-background-color";
      value = "var(--angst-bg)";
    }
    {
      name = "tab-background-color-selected";
      value = "var(--angst-active-bg)";
    }
    {
      name = "tab-background-color-hover";
      value = "var(--angst-hover-bg)";
    }
    {
      name = "tab-text-color";
      value = "var(--angst-fg)";
    }
    {
      name = "tab-text-color-selected";
      value = "var(--angst-fg)";
    }
    {
      name = "tab-text-color-hover";
      value = "var(--angst-fg)";
    }
    {
      name = "tab-border-color";
      value = "transparent";
    }
    {
      name = "chrome-content-separator-color";
      value = "transparent";
    }
    {
      name = "sidebar-background-color";
      value = "var(--angst-bg)";
    }
    {
      name = "sidebar-text-color";
      value = "var(--angst-fg)";
    }
    {
      name = "sidebar-border-color";
      value = "transparent";
    }
    {
      name = "toolbox-border-bottom-color";
      value = "transparent";
    }
    {
      name = "titlebar-color";
      value = "var(--angst-fg)";
    }
    {
      name = "titlebar-background-color";
      value = "var(--angst-bg)";
    }
    {
      name = "background-color-canvas";
      value = "var(--angst-bg)";
    }
    {
      name = "background-color-content";
      value = "var(--angst-bg)";
    }
    {
      name = "card-background-color";
      value = "var(--angst-bg-variant)";
    }
    {
      name = "card-text-color";
      value = "var(--angst-fg)";
    }
    {
      name = "card-border-color";
      value = "transparent";
    }
    {
      name = "panel-background-color";
      value = "var(--angst-bg-variant)";
    }
    {
      name = "panel-text-color";
      value = "var(--angst-fg)";
    }
    {
      name = "in-content-page-background";
      value = "var(--angst-bg)";
    }
    {
      name = "in-content-page-color";
      value = "var(--angst-fg)";
    }
    {
      name = "in-content-text-color";
      value = "var(--angst-fg)";
    }
    {
      name = "in-content-box-background";
      value = "var(--angst-active-bg)";
    }
    {
      name = "in-content-box-text-color";
      value = "var(--angst-fg)";
    }
    {
      name = "in-content-box-border-color";
      value = "transparent";
    }
    {
      name = "in-content-border-color";
      value = "transparent";
    }
    {
      name = "in-content-item-hover";
      value = "var(--angst-hover-bg)";
    }
    {
      name = "in-content-item-hover-text";
      value = "var(--angst-fg)";
    }
    {
      name = "in-content-item-selected";
      value = "var(--angst-active-bg)";
    }
    {
      name = "in-content-item-selected-text";
      value = "var(--angst-fg)";
    }
    {
      name = "in-content-primary-button-background";
      value = "var(--angst-accent)";
    }
    {
      name = "in-content-primary-button-text-color";
      value = "var(--angst-bg)";
    }
    {
      name = "in-content-primary-button-background-hover";
      value = "var(--angst-accent-variant)";
    }
    {
      name = "in-content-primary-button-background-active";
      value = "var(--angst-accent-variant)";
    }
    {
      name = "color-accent-primary";
      value = "var(--angst-accent)";
    }
    {
      name = "color-accent-primary-hover";
      value = "var(--angst-accent-variant)";
    }
    {
      name = "color-accent-primary-active";
      value = "var(--angst-accent-variant)";
    }
    {
      name = "button-background-color";
      value = "var(--angst-bg-variant)";
    }
    {
      name = "button-background-color-hover";
      value = "var(--angst-hover-bg)";
    }
    {
      name = "button-background-color-active";
      value = "var(--angst-active-bg)";
    }
    {
      name = "button-text-color";
      value = "var(--angst-fg)";
    }
    {
      name = "button-text-color-hover";
      value = "var(--angst-fg)";
    }
    {
      name = "button-text-color-active";
      value = "var(--angst-fg)";
    }
    {
      name = "input-background-color";
      value = "var(--angst-bg-variant)";
    }
    {
      name = "input-color";
      value = "var(--angst-fg)";
    }
    {
      name = "input-border-color";
      value = "transparent";
    }
  ];

  mkLine = v: theme.mkVar v.name v.value (v.important or true);

  rootVarsText = builtins.concatStringsSep "\n" (map mkLine (angstVars ++ chromeVars));

  rootBlock = ''
    :root {
      color-scheme: ${theme.colorScheme} !important;
    ${rootVarsText}
    }'';

  rules = ''
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
    }'';
in
''
  ${rootBlock}
  ${rules}
''
