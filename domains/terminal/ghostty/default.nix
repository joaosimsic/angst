{ config, lib, pkgs, ... }:

let
  cfg = config.domains.terminal.ghostty;
in
{
  options.domains.terminal.ghostty = {
    enable = lib.mkEnableOption "Ghostty terminal emulator";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.ghostty
    ];
  };
}
