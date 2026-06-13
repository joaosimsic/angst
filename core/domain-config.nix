{ config, lib, pkgs, flakeSelf, ... }:

let
  cfg = config.domainConfig;
in
{
  options.domainConfig = {
    sourceDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/angst";
      description = "Path to the config source repository root";
    };
  };

  config = {
    home.activation.seedAngstRepo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      HOST_SRC="/host${config.home.homeDirectory}/proj/angst"
      ANGST_SRC=${lib.cleanSourceWith {
        src = flakeSelf;
        filter =
          path: type:
          let
            base = builtins.baseNameOf path;
          in
          base != ".git" && base != "result" && !(lib.hasSuffix ".qcow2" base);
      }}
      ANGST_DST=${lib.escapeShellArg cfg.sourceDir}

      # Skip if running in VM (host virtiofs available) or already seeded
      if [ ! -d "$HOST_SRC" ] && [ ! -f "$ANGST_DST/flake.nix" ]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$ANGST_DST")"
        $DRY_RUN_CMD cp -a "$ANGST_SRC" "$ANGST_DST"
        $DRY_RUN_CMD chmod -R u+w "$ANGST_DST"
      fi
    '';
  };
}
