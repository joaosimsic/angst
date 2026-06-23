{ config, lib, pkgs, ... }:

let
  cfg = config.capabilities.clipboard;
in
{
  options.capabilities.clipboard = {
    enable = lib.mkEnableOption "Clipboard tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      xclip
      xsel
    ];
  };
}

