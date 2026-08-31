{
  config,
  lib,
  pkgs,
  themesLib,
  inputs,
  hostType,
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
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # nixGL wrapper for non-NixOS (e.g. mint type="home" + NVIDIA GT 710 / 470)
      # On NixOS (hostType == "nixos") this stays null -> config.lib.nixGL.wrap is a no-op (pure)
      targets.genericLinux.nixGL = lib.mkIf (hostType != "nixos") {
        packages = inputs.nixGL.packages;
        defaultWrapper = "nvidia";
        installScripts = [ "nvidia" ];
      };
    }
    {
      programs.firefox = {
        enable = true;
        languagePacks = [
          "en-US"
          "pt-BR"
        ];
        package =
          let
            base = pkgs.firefox.override {
              extraPrefs = builtins.readFile ./extra-prefs.js;
            };
          in
          # Wrap via nixGL on non-NixOS to expose host NVIDIA GL (fixes Exhausted GL driver options)
          # On NixOS wrapper is no-op (pure) because targets.genericLinux.nixGL.packages == null
          config.lib.nixGL.wrap base;
      configPath = ".mozilla/firefox";
      policies = policies.common // policies.homeExtra;
      profiles.default = {
        id = 0;
        name = "default";
        isDefault = true;
        inherit settings;
        inherit userChrome userContent;
        extensions.settings."addon@darkreader.org" = {
          force = true;
          settings = {
            enabledByDefault = true;
            enabledFor = [ ];
            disabledFor = [ "github.com" ];
            syncSettings = false;
          };
        };
      };
    };
    home = {
      packages = [ pkgs.tridactyl-native ];
      file = {
        ".mozilla/native-messaging-hosts/tridactyl.json".source =
          "${pkgs.tridactyl-native}/lib/mozilla/native-messaging-hosts/tridactyl.json";
        ".mozilla/firefox/default/tridactylrc".text = tridactyl.rc;
        ".mozilla/firefox/default/tridactyl/themes/angst.css".text = tridactyl.css;
      };
    };
    xdg.configFile = {
      "tridactyl/tridactylrc".text = tridactyl.rc;
      "tridactyl/themes/angst.css".text = tridactyl.css;
    };
    }
  ]);
}
