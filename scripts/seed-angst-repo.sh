if [ -d "$HOST_SRC" ]; then
    [ -e "$ANGST_DST" ] && $DRY_RUN_CMD rm -rf "$ANGST_DST"
    $DRY_RUN_CMD mkdir -p "$(dirname "$ANGST_DST")"
    $DRY_RUN_CMD ln -sfn "$HOST_SRC" "$ANGST_DST"
elif [ -d "$ANGST_DST/.git" ]; then
    :
else
    ANGST_DST_ABS="$(cd "$(dirname "$ANGST_DST")" 2>/dev/null && pwd -P 2>/dev/null)/$(basename "$ANGST_DST")"
    CWD_ABS="$(pwd -P 2>/dev/null || printf '%s' "$PWD")"
    case "$CWD_ABS" in
    "$ANGST_DST_ABS" | "$ANGST_DST_ABS"/*)
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
fi
