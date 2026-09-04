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
      exec = "${paperPkg}/bin/paper-desktop";
      icon = "paper";
      categories = [
        "Graphics"
        "Development"
      ];
      startupNotify = true;
      terminal = false;
    };
  };
}
