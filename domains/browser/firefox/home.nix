{
  config,
  lib,
  pkgs,
  themesLib,
  ...
}:
let
  cfg = config.domains.browser.firefox;
  theme = import ./theme.nix { inherit config themesLib; };
  userChrome = import ./chrome.nix { inherit theme; };
  userContent = import ./content.nix { inherit theme; };
  tridactyl = import ./tridactyl.nix { inherit theme config; };
  policies = import ./policies.nix;
  settings = import ./settings.nix { inherit theme; };
in
{
  config = lib.mkIf cfg.enable {
    programs.firefox = {
      enable = true;
      package = pkgs.firefox.override {
        extraPrefs = builtins.readFile ./extra-prefs.js;
      };
      configPath = ".mozilla/firefox";
      policies = policies.common // policies.homeExtra;
      profiles.default = {
        id = 0;
        name = "default";
        isDefault = true;
        inherit settings;
        inherit userChrome userContent;
      };
    };
    home.file.".mozilla/firefox/default/tridactylrc".text = tridactyl.rc;
    home.file.".mozilla/firefox/default/tridactyl/themes/angst.css".text = tridactyl.css;
    xdg.configFile."tridactyl/themes/angst.css".text = tridactyl.css;
  };
}
