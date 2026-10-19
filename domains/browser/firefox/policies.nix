{
  common = {
    DisableTelemetry = true;
    DisableFirefoxStudies = true;
    DontCheckDefaultBrowser = true;
    DisableAppUpdate = true;
    DisplayBookmarksToolbar = "always";
    NoDefaultBookmarks = true;
    Homepage = {
      URL = "about:home";
      StartPage = "homepage";
    };
    NewTabPage = true;
    FirefoxHome = {
      Search = true;
      TopSites = true;
      SponsoredTopSites = false;
      Highlights = true;
      Pocket = false;
      SponsoredPocket = false;
      Snippets = false;
      Locked = false;
    };
    OverrideFirstRunPage = "";
    OverridePostUpdatePage = "";
  };

  homeExtra = {
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
}
