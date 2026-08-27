{
  config,
  lib,
  ...
}:
let
  cfg = config.domains.browser.firefox;
  policies = import ./policies.nix;
in
{
  options.domains.browser.firefox.enable = lib.mkEnableOption "Firefox browser (system side)";
  config = lib.mkIf cfg.enable {
    programs.firefox = {
      enable = true;
      policies = policies.common;
    };
  };
}
