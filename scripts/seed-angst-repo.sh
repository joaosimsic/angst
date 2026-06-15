if [ -d "$HOST_SRC" ]; then exit 0; fi
if [ -f "$ANGST_DST/flake.nix" ] && [ -s "$ANGST_DST/flake.nix" ]; then exit 0; fi
[ -e "$ANGST_DST" ] && $DRY_RUN_CMD rm -rf "$ANGST_DST"
$DRY_RUN_CMD mkdir -p "$(dirname "$ANGST_DST")"
$DRY_RUN_CMD cp -a "$ANGST_SRC" "$ANGST_DST"
$DRY_RUN_CMD chmod -R u+w "$ANGST_DST"
