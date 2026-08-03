if [ -d "$HOST_SRC" ]; then
  # VM host mount: the repo is served read-only from the host at /host...;
  # link the deploy target to it.
  [ -e "$ANGST_DST" ] && $DRY_RUN_CMD rm -rf "$ANGST_DST"
  $DRY_RUN_CMD mkdir -p "$(dirname "$ANGST_DST")"
  $DRY_RUN_CMD ln -sfn "$HOST_SRC" "$ANGST_DST"
elif [ -d "$ANGST_DST/.git" ]; then
  # The deploy target is the live working repo. It is already current, so leave
  # it untouched: local/config.nix and any uncommitted changes stay put, and the
  # render step regenerates the domain configs in place.
  :
else
  # local/config.nix is machine-specific and gitignored, so it is not part of
  # the flake source. Back it up before replacing the deploy target.
  BACKUP=""
  if [ -f "$ANGST_DST/local/config.nix" ] && [ -z "$DRY_RUN_CMD" ]; then
    BACKUP="$(mktemp -t angst-config.XXXXXX)"
    cp "$ANGST_DST/local/config.nix" "$BACKUP"
  fi

  # Never remove the current working directory: the activation keeps running
  # from it, and deleting it makes the switch fail with 'cannot get cwd'. When
  # the switch is run from inside the deploy target, refresh it in place.
  ANGST_DST_ABS="$(cd "$(dirname "$ANGST_DST")" 2>/dev/null && pwd -P 2>/dev/null)/$(basename "$ANGST_DST")"
  CWD_ABS="$(pwd -P 2>/dev/null || printf '%s' "$PWD")"
  case "$CWD_ABS" in
    "$ANGST_DST_ABS"|"$ANGST_DST_ABS"/*)
      $DRY_RUN_CMD mkdir -p "$ANGST_DST"
      $DRY_RUN_CMD cp -a "$ANGST_SRC/." "$ANGST_DST/"
      $DRY_RUN_CMD chmod -R u+w "$ANGST_DST"
      ;;
    *)
      [ -e "$ANGST_DST" ] && $DRY_RUN_CMD rm -rf "$ANGST_DST"
      $DRY_RUN_CMD mkdir -p "$(dirname "$ANGST_DST")"
      $DRY_RUN_CMD cp -a "$ANGST_SRC" "$ANGST_DST"
      $DRY_RUN_CMD chmod -R u+w "$ANGST_DST"
      ;;
  esac

  if [ -n "$BACKUP" ]; then
    $DRY_RUN_CMD mkdir -p "$ANGST_DST/local"
    $DRY_RUN_CMD cp "$BACKUP" "$ANGST_DST/local/config.nix"
    $DRY_RUN_CMD rm -f "$BACKUP"
  fi
fi
