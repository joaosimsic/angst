{
  config,
  lib,
  ...
}:

let
  cfg = config.domains.gamedev.blender;
in
{
  config = lib.mkIf cfg.enable {
    xdg.mimeApps = {
      enable = true;
      defaultApplications."application/x-blender" = "blender.desktop";
      associations.added."application/x-blender" = "blender.desktop";
    };
  };
}
