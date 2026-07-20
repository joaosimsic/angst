{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.llm.opencode.enable {
    home.packages = [ pkgs.opencode ];
  };
}
