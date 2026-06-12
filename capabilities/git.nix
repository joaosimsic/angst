{ config, lib, pkgs, ... }:

let
  cfg = config.capabilities.git;
in
{
  options.capabilities.git = {
    enable = lib.mkEnableOption "Git version control";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      git
      lazygit
    ];
  };
}