{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.agents.opencode.enable {
    home.packages = [ pkgs.opencode ];

    home.sessionVariables = {
      OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";
    };
  };
}
