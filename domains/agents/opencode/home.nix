{
  config,
  lib,
  pkgs,
  ...
}:

let
  opencode = import ./wrapper.nix {
    inherit pkgs;
    opencodePackage = pkgs.opencode;
  };
in
{
  config = lib.mkIf config.domains.agents.opencode.enable {
    home.packages = [
      opencode
      pkgs.rtk
    ];

    xdg.configFile = import ./skills.nix { inherit lib pkgs; };

    home.sessionVariables = {
      OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";
    };
  };
}
