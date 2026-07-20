{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.font.family = lib.mkOption {
    type = lib.types.str;
    default = "JetBrainsMono Nerd Font";
    description = "Global monospace font family for domain-rendered configs and fontconfig.";
  };

  config = {
    environment.systemPackages = [ pkgs.nerd-fonts.jetbrains-mono ];

    fonts.fontconfig.defaultFonts.monospace = [ config.font.family ];
  };
}
