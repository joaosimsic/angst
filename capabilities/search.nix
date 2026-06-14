{ config, lib, pkgs, ... }:

let
  cfg = config.capabilities.search;
in
{
  options.capabilities.search = {
    enable = lib.mkEnableOption "Search tools (fd, ripgrep)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      fd
      ripgrep
    ];
  };
}
