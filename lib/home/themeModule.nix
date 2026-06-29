{ lib, themesLib, hostTheme, ... }:

{
  options.theme = lib.mkOption {
    type = lib.types.enum (lib.attrNames themesLib.themes);
    default = hostTheme;
    description = "Color theme for domain-rendered configs.";
  };
}
