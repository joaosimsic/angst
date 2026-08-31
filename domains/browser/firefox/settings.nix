{ theme }:
{
  "browser.startup.homepage" = "about:home";
  "browser.startup.page" = 1;
  "browser.newtabpage.enabled" = true;
  "browser.startup.homepage_override.mstone" = "ignore";
  "browser.toolbars.bookmarks.visibility" = "always";
  "devtools.chrome.enabled" = true;
  "devtools.debugger.remote-enabled" = true;
  "devtools.debugger.prompt-connection" = false;
  "browser.bookmarks.restore_default_bookmarks" = false;
  "browser.bookmarks.addedImportButton" = true;
  "browser.sessionstore.resume_from_crash" = true;
  "browser.warnOnQuit" = true;
  "browser.tabs.warnOnClose" = true;
  "browser.tabs.warnOnCloseOtherTabs" = true;
  "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
  "browser.uidensity" = 0;
  "browser.theme.toolbar-theme" = theme.toolbarThemeVal;
  "browser.theme.content-theme" = theme.contentThemeVal;
  "browser.in-content.dark-mode" = theme.isDark;
  "layout.css.prefers-color-scheme.content-override" = theme.contentOverrideVal;
  "ui.systemUsesDarkTheme" = theme.systemDarkVal;
  "extensions.autoDisableScopes" = 0;
  "sidebar.revamp" = true;
  "sidebar.verticalTabs" = true;
  "sidebar.visibility" = "always-show";
  "webgl.disabled" = false;
  "webgl.force-enabled" = true;
  "webgl.enable-webgl2" = true;
  "layers.acceleration.force-enabled" = true;
  "gfx.webrender.all" = true;
  "intl.accept_languages" = "en-US, en, pt-BR";
  "intl.locale.requested" = "en-US,pt-BR";
  "spellchecker.dictionary" = "en-US";
}
