{ ... }:

let
  mkDomainActivation =
    {
      lib,
      configDir,
      meta,
      category,
      name,
      homeDirectory,
    }:
    let
      hasXdg = (meta.xdg or null) != null;
      hasXdgFile = (meta.xdgFile or null) != null;
      hasConfigDir = builtins.pathExists configDir;

      mkXdgScript = xdgName: ''
        # Domain ${category}/${name}: directory symlink
        if [ -d "/host${homeDirectory}/proj/angst" ]; then
          CFG_SRC="/host${homeDirectory}/proj/angst"
        else
          CFG_SRC="${homeDirectory}/.config/angst"
        fi

        DOMAIN_SRC="$CFG_SRC/domains/${category}/${name}/config"
        TARGET="${homeDirectory}/.config/${xdgName}"

        if [ ! -d "$DOMAIN_SRC" ]; then
          echo "domains.${category}.${name}: config source not found at $DOMAIN_SRC" >&2
          exit 1
        fi

        # Backup existing non-symlink directory
        if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
          $DRY_RUN_CMD mv "$TARGET" "$TARGET.hm-backup"
        fi

        $DRY_RUN_CMD mkdir -p "$(dirname "$TARGET")"
        $DRY_RUN_CMD ln -sfn "$DOMAIN_SRC" "$TARGET"
      '';

      mkXdgFileScript = xdgFile: ''
        # Domain ${category}/${name}: single-file symlink
        if [ -d "/host${homeDirectory}/proj/angst" ]; then
          CFG_SRC="/host${homeDirectory}/proj/angst"
        else
          CFG_SRC="${homeDirectory}/.config/angst"
        fi

        DOMAIN_SRC="$CFG_SRC/domains/${category}/${name}/config"
        TARGET="${homeDirectory}/.config/${xdgFile}"

        # Ensure source dir exists
        $DRY_RUN_CMD mkdir -p "$DOMAIN_SRC"

        if [ ! -f "$DOMAIN_SRC/${xdgFile}" ]; then
          echo "domains.${category}.${name}: config file not found at $DOMAIN_SRC/${xdgFile}" >&2
          exit 1
        fi

        # Backup existing non-symlink
        if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
          $DRY_RUN_CMD mv "$TARGET" "$TARGET.hm-backup"
        fi

        $DRY_RUN_CMD mkdir -p "$(dirname "$TARGET")"
        $DRY_RUN_CMD ln -sf "$DOMAIN_SRC/${xdgFile}" "$TARGET"
      '';

      activationScript =
        if hasXdg then
          mkXdgScript meta.xdg
        else if hasXdgFile then
          mkXdgFileScript meta.xdgFile
        else
          "";
    in
    if !hasConfigDir || (!hasXdg && !hasXdgFile) || (meta.customXdg or false) then
      { }
    else
      {
        home.activation."domain-${category}-${name}" = lib.mkDefault (
          lib.hm.dag.entryAfter [ "seedAngstRepo" "writeBoundary" ] activationScript
        );
      };
in
{
  inherit mkDomainActivation;
}
