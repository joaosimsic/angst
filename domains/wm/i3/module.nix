{ config, lib, ... }:

let
  cfg = config.domains.wm.i3;
in
{
  config = lib.mkIf cfg.enable {
    home.activation."domain-wm-i3" = lib.hm.dag.entryAfter [
      "seedAngstRepo"
      "writeBoundary"
    ] ''
      if [ -d "/host${config.home.homeDirectory}/proj/angst" ]; then
        CFG_SRC="/host${config.home.homeDirectory}/proj/angst"
      else
        CFG_SRC="${config.home.homeDirectory}/.config/angst"
      fi

      DOMAIN_SRC="$CFG_SRC/domains/wm/i3/config"
      TARGET="${config.home.homeDirectory}/.config/i3"

      if [ ! -d "$DOMAIN_SRC" ]; then
        echo "domains.wm.i3: config source not found at $DOMAIN_SRC" >&2
        exit 1
      fi

      if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
        $DRY_RUN_CMD mv "$TARGET" "$TARGET.hm-backup"
      fi

      $DRY_RUN_CMD mkdir -p "$(dirname "$TARGET")"
      $DRY_RUN_CMD ln -sfn "$DOMAIN_SRC" "$TARGET"
    '';
  };
}
