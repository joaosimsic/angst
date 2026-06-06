{ pkgs, capabilities, ... }:

{
  imports = [
    capabilities.audio
    capabilities.network
    capabilities.git
  ]
}
