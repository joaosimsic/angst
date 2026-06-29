{ config, lib, pkgs, ... }:

let
  cfg = config.domains.session.x11;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      hsetroot
      xclip
    ];
  };
}
