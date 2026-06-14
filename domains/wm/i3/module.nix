{ config, lib, pkgs, themesLib, renderTemplate, monitors, templateTokens, ... }:

let
  cfg = config.domains.wm.i3;

  tokens = templateTokens {
    inherit lib themesLib;
    theme = config.theme;
    fontFamily = config.font.family;
  };

  monitorOrder = lib.unique (
    lib.filter (n: lib.hasAttr n monitors) (
      [ "primary" "secondary" ] ++ lib.attrNames monitors
    )
  );

  monitorLine =
    name:
    let
      m = monitors.${name};
    in
    "exec --no-startup-id xrandr --output ${m.name} --mode ${m.resolution} --rate ${toString m.refreshRate} --pos ${m.position}";

  monitorsConf =
    if monitors == { } then
      "# no monitor overrides configured"
    else
      lib.concatStringsSep "\n" (map monitorLine monitorOrder);

  body = renderTemplate {
    inherit lib;
    templatePath = ./config/config.template;
    inherit tokens;
  };

  fragments = config.domains.wm._i3.configLines;

  i3Config = body + "\n" + lib.concatStringsSep "\n" fragments;

  i3ConfigFile = pkgs.writeText "i3-config" i3Config;
  monitorsConfFile = pkgs.writeText "i3-monitors" monitorsConf;
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

      # Copy build-time merged config (template + fragments + monitors)
      $DRY_RUN_CMD cp -f ${i3ConfigFile} "$TARGET/config"
      $DRY_RUN_CMD cp -f ${monitorsConfFile} "$TARGET/monitors.conf"
      $DRY_RUN_CMD chmod u+w "$TARGET/config" "$TARGET/monitors.conf"
    '';
  };
}
