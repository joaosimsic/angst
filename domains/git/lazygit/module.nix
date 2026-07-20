{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.git.lazygit.enable {
    home.packages = [ pkgs.lazygit ];
  };
}
