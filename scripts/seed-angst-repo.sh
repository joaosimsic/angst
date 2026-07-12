if [ ! -d "$HOST_SRC" ]; then
  [ -e "$ANGST_DST" ] && $DRY_RUN_CMD rm -rf "$ANGST_DST"
  $DRY_RUN_CMD mkdir -p "$(dirname "$ANGST_DST")"
  $DRY_RUN_CMD cp -a "$ANGST_SRC" "$ANGST_DST"
  $DRY_RUN_CMD chmod -R u+w "$ANGST_DST"
fi
