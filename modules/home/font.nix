{
  config,
  lib,
  pkgs,
  ...
}:

let
  fontsLib = import ./fonts.nix;
in
{
  options.font.family = lib.mkOption {
    type = lib.types.str;
    default = fontsLib.defaultFamily;
    description = "Global monospace font family for domain-rendered configs and fontconfig.";
  };

  config = {
    home.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

    fonts.fontconfig.defaultFonts.monospace = [ config.font.family ];
  };
}
