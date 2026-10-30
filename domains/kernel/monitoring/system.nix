{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.kernel.monitoring;
in
{
  options.domains.kernel.monitoring = {
    enable = lib.mkEnableOption "Monitoring tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      btop
    ];
  };
}
