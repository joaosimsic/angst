{ config, lib, pkgs, ... }:

let
  cfg = config.domains.terminal.zellij;
in
{
  options.domains.terminal.zellij = {
    enable = lib.mkEnableOption "Zellij terminal multiplexer";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.zellij
    ];
  };
}

