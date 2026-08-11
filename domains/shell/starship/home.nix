{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.shell.starship.enable {
    home.packages = [ pkgs.starship ];
  };
}
