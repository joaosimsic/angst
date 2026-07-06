{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.shell.nushell.enable {
    home.packages = [ pkgs.nushell ];
  };
}
