{ config, lib, pkgs, capabilities, ... }:

{
  imports = [
    capabilities.audio
    capabilities.network
    capabilities.git
  ];

  capabilities.audio.enable = lib.mkDefault true;
  capabilities.network.enable = lib.mkDefault true;
  capabilities.git.enable = lib.mkDefault true;
}
