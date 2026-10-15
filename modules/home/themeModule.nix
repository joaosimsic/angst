{
  lib,
  themeSys,
  hostTheme,
}:

{
  options.theme = lib.mkOption {
    type = lib.types.enum (lib.attrNames themeSys.themes);
    default = hostTheme;
    description = "Color theme for domain-rendered configs.";
  };
}
