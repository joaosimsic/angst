{
  config,
  lib,
  pkgs,
  store,
  ...
}:

let
  cfg = config.domains.design.paper;
  paperPkgRaw = pkgs.callPackage ./package.nix { };
  browserPkg = store.defaultBrowser or "firefox";
  paperPkg = pkgs.symlinkJoin {
    name = "paper-desktop-wrapped";
    paths = [ paperPkgRaw ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/paper-desktop \
        --set BROWSER "${browserPkg}" \
        --run 'export XDG_DATA_DIRS="$HOME/.nix-profile/share:$HOME/.local/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"' \
        --run 'export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"'
    '';
  };
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
