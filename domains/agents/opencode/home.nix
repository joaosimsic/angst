{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.agents.opencode.enable {
    home.packages = [
      pkgs.opencode
      pkgs.rtk
    ];

    xdg.configFile = import ./skills.nix { inherit lib pkgs; };

    home.sessionVariables = {
      OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";
    };
  };
}
