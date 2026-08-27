{
  config,
  lib,
  ...
}:
let
  cfg = config.domains.browser.firefox;
in
{
  options.domains.browser.firefox.enable = lib.mkEnableOption "Firefox browser (system side)";
  config = lib.mkIf cfg.enable {
    programs.firefox = {
      enable = true;
      policies = {
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
    };
  };
}
