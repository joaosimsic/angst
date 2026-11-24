{
  config,
  lib,
  pkgs,
  store ? { },
  themesLib,
  ...
}:

let
  cfg = config.domains.design.paper;
  paperPkg = import ./launcher.nix {
    inherit pkgs lib;
    browser = store.defaultBrowser or "firefox";
    isDark = (themesLib.get config.theme).isDark;
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ paperPkg ];

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/paper" = "paper-desktop.desktop";
        "x-scheme-handler/burp" = "install4j_1hv7l1i-BurpSuiteCommunity.desktop";
        "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      };
      associations.added = {
        "x-scheme-handler/paper" = "paper-desktop.desktop";
        "x-scheme-handler/burp" = "install4j_1hv7l1i-BurpSuiteCommunity.desktop";
        "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      };
    };

    xdg.desktopEntries.paper-desktop = {
      name = "Paper";
      genericName = "Design Tool";
      comment = "Paper Desktop – connected canvas (paper.design)";
      exec = "${paperPkg}/bin/paper-desktop %U";
      icon = "applications-graphics";
      categories = [
        "Graphics"
        "Development"
      ];
      mimeType = [ "x-scheme-handler/paper" ];
      startupNotify = true;
      terminal = false;
      settings.StartupWMClass = "Paper";
    };
  };
}
