{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.sql-client.rainfrog.enable {
    home.packages = [ pkgs.rainfrog ];
  };
}
