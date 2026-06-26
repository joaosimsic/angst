{ config, lib, pkgs, ... }:

let
  cfg = config.domains.files.yazi;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.yazi ];
  };
}

