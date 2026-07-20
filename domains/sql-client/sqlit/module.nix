{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.sql-client.sqlit.enable {
    home.packages = [ pkgs.sqlit-tui ];
  };
}
