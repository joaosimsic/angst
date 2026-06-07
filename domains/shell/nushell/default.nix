{ config, lib, pkgs, ... }:

let
  cfg = config.domains.shell.nushell;
in 
{
  options.domains.shell.nushell = {
    enable = lib.mkEnableOption "Nushell configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.nushell = {
      enable = true;
      configFile.source = ./config/config.nu;
      envFile.source = ./config/env.nu;
    };

    programs.starship = {
      enable = true;
      settings = pkgs.lib.importTOML ./config/starship.toml;
    };
  };
}
