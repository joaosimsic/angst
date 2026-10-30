{
  lib,
  themeNames,
  themeDefault,
  ...
}:

{
  imports = [
    ./gtk.nix
    ./qt.nix
  ];

  options.theme = lib.mkOption {
    type = lib.types.enum themeNames;
    default = themeDefault;
    description = "Color theme for domain-rendered configs.";
  };
}
