{
  config,
  lib,
  ...
}:

let
  cfg = config.domains.wm.i3;
in
{
  options.domains.wm.i3 = {
    enable = lib.mkEnableOption "i3 window manager (system side)";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.enable || config.domains.system.graphical.enable;
        message = "domains.wm.i3 requires domains.system.graphical to be enabled";
      }
    ];

    services.xserver.windowManager.i3.enable = true;
  };
}
