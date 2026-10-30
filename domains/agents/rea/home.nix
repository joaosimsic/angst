{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.domains.agents.rea.enable {
    home.packages = [
      pkgs.nodejs_24
      pkgs.procps
    ];

    home.sessionVariables = {
      REA_GHIDRA_STARTUP_TIMEOUT_MS = "900000";
    };
  };
}
