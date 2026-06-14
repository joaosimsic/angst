{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.domains.terminal.zellij.enable {
    home.packages = [ pkgs.zellij ];
  };
}
