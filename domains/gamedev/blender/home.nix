{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.gamedev.blender;
  mcp = pkgs.callPackage ./mcp-for-blender.nix { };
  blenderUserDir = ".config/blender/${lib.versions.majorMinor pkgs.blender.version}";
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ mcp ];

    home.file = {
      "${blenderUserDir}/scripts/addons/blender_mcp.py".source =
        "${mcp}/share/blender/scripts/addons/blender_mcp.py";

      "${blenderUserDir}/scripts/startup/angst_blender_mcp.py".text = ''
        import addon_utils
        import bpy


        def _enable_blender_mcp():
            if not addon_utils.check("blender_mcp")[1]:
                addon_utils.enable("blender_mcp", default_set=True, persistent=True)
            return None


        if not addon_utils.check("blender_mcp")[1]:
            bpy.app.timers.register(_enable_blender_mcp, first_interval=1.0)
      '';
    };

    xdg.mimeApps = {
      enable = true;
      defaultApplications."application/x-blender" = "blender.desktop";
      associations.added."application/x-blender" = "blender.desktop";
    };
  };
}
