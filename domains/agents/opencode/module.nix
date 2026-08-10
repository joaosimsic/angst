{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.agents.opencode.enable {
    home.packages = [ pkgs.opencode ];
  };
}
