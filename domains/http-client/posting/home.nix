{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.http-client.posting.enable {
    home.packages = [ pkgs.posting ];
  };
}
