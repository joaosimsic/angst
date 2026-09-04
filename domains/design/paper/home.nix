{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.design.paper;
  paperPkg = pkgs.callPackage ./package.nix { };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ paperPkg ];

    xdg.desktopEntries.paper-desktop = {
      name = "Paper";
      genericName = "Design Tool";
      comment = "Paper Desktop – connected canvas (paper.design)";
      exec = "${paperPkg}/bin/paper-desktop %U";
      icon = "paper";
      categories = [
        "Graphics"
        "Development"
      ];
      mimeType = [ "x-scheme-handler/paper" ];
      startupNotify = true;
      terminal = false;
    };

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/paper" = "paper-desktop.desktop";
        # preserve existing user associations (avoid overwrite on activation)
        "x-scheme-handler/burp" = "install4j_1hv7l1i-BurpSuiteCommunity.desktop";
        "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      };
      associations.added = {
        "x-scheme-handler/paper" = "paper-desktop.desktop";
        "x-scheme-handler/burp" = "install4j_1hv7l1i-BurpSuiteCommunity.desktop";
        "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      };
    };
  };
}
