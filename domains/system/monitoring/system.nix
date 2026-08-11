{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.system.monitoring;
in
{
  options.domains.system.monitoring = {
    enable = lib.mkEnableOption "Monitoring tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      btop
    ];
  };
}
