{ config, lib, pkgs, ... }:

let
  cfg = config.domains.shell.nushell;
in 
{
  options.domains.shell.nushell = {
    enable = lib.mkEnableOption "Nushell configuration environment";
  };

  config = lib.mkIf cfg.enable {
    programs.nushell = {
      enable = true;
    };

    programs.starship = {
      enable = true;
      enableNushellIntegration = true;
    };
  };
}
