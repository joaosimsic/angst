{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.games.steam;
in
{
  options.domains.games.steam = {
    enable = lib.mkEnableOption "Steam + Proton gaming stack (CS2, Overwatch 2)";
  };

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      protontricks.enable = true;
    };

    programs.gamemode.enable = true;
  };
}
