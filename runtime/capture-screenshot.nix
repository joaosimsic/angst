{
  mkScript,
  pkgs,
  lib,
}:
{
  backend,
  targetDir,
  copyToClipboard,
  saveToFile,
  interactive,
  name,
}:
mkScript {
  inherit name;
  runtimeInputs =
    with pkgs;
    [
      libnotify
      coreutils
      gnugrep
      gnused
    ]
    ++ lib.optionals (backend == "maim") [
      maim
      slop
      xdotool
      xclip
      xsel
    ]
    ++ lib.optionals (backend == "grim") [
      grim
      slurp
      wl-clipboard
    ]
    ++ lib.optionals (backend == "portal") [
      xdg-utils
      dbus
      libnotify
    ]
    ++ lib.optionals (backend == "auto") [
      maim
      slop
      xdotool
      xclip
      xsel
      grim
      slurp
      wl-clipboard
      xdg-utils
      dbus
    ];
  text = ''
    set -euo pipefail

    MODE="''${1:-region}"
    case "$MODE" in
      --region|region) MODE="region" ;;
      --fullscreen|fullscreen|full) MODE="fullscreen" ;;
      --window|window) MODE="window" ;;
      --color|color|pick) MODE="color" ;;
      -h|--help|help)
        echo "Usage: angst-screenshot [region|fullscreen|window|color]"
        echo "  region     - select area (maim -s / grim+slurp)"
        echo "  fullscreen - whole screen"
        echo "  window     - active window (X11 only, falls back to region)"
        echo "Env: ANGST_SCREENSHOT_BACKEND=auto|portal|maim|grim overrides config"
        exit 0
        ;;
      *) echo "Unknown mode: $MODE" >&2; exit 1 ;;
    esac

    BACKEND_CFG="${backend}"
    BACKEND="''${ANGST_SCREENSHOT_BACKEND:-$BACKEND_CFG}"

    TARGET_DIR="${targetDir}"
    TARGET_DIR_EVAL=$(eval echo "$TARGET_DIR")
    mkdir -p "$TARGET_DIR_EVAL"

    TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
    OUT_FILE="$TARGET_DIR_EVAL/$TIMESTAMP.png"

    COPY_TO_CLIPBOARD="${if copyToClipboard then "1" else "0"}"
    SAVE_TO_FILE="${if saveToFile then "1" else "0"}"
    INTERACTIVE="${if interactive then "1" else "0"}"

    if [ "$BACKEND" = "auto" ]; then
      if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
        if command -v grim >/dev/null 2>&1; then
          BACKEND="grim"
        else
          BACKEND="portal"
        fi
      elif [ "''${XDG_SESSION_TYPE:-}" = "wayland" ]; then
        BACKEND="portal"
      else
        if command -v maim >/dev/null 2>&1; then
          BACKEND="maim"
        else
          BACKEND="portal"
        fi
      fi
    fi

    TMP_FILE=""
    cleanup() {
      if [ -n "$TMP_FILE" ] && [ -f "$TMP_FILE" ] && [ "$SAVE_TO_FILE" != "1" ]; then
        rm -f "$TMP_FILE"
      fi
    }
    trap cleanup EXIT

    capture_maim() {
      case "$MODE" in
        region) maim -s "$1" ;;
        fullscreen) maim "$1" ;;
        window) maim -i "$(xdotool getactivewindow 2>/dev/null || echo "")" "$1" 2>/dev/null || maim -s "$1" ;;
        color) maim -s "$1" ;;
      esac
    }

    capture_grim() {
      case "$MODE" in
        region)
          GEOM=$(slurp 2>/dev/null || echo "")
          if [ -z "$GEOM" ]; then echo "slurp cancelled" >&2; exit 1; fi
          grim -g "$GEOM" "$1"
          ;;
        fullscreen) grim "$1" ;;
        window) grim -g "$(slurp 2>/dev/null || echo "")" "$1" ;;
        color) grim -g "$(slurp -p 2>/dev/null || echo "")" "$1" ;;
      esac
    }

    capture_portal() {
      URI=""
      if command -v gdbus >/dev/null 2>&1; then
        OPTIONS="{}"
        if [ "$INTERACTIVE" = "1" ]; then
          OPTIONS="{'interactive': <true>}"
        fi
        OUT=$(gdbus call --session --dest org.freedesktop.portal.Desktop \
          --object-path /org/freedesktop/portal/desktop \
          --method org.freedesktop.portal.Screenshot.Screenshot \
          "" "$OPTIONS" 2>/dev/null || true)
        URI=$(echo "$OUT" | grep -o "file://[^']*" | head -n1 || true)
        URI=''${URI#file://}
        URI=$(printf '%b' "''${URI//%/\\x}" 2>/dev/null || echo "$URI")
        if [ -n "$URI" ] && [ -f "$URI" ]; then
          cp "$URI" "$1"
          return 0
        fi
      fi
      if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
        capture_grim "$1"
      else
        capture_maim "$1"
      fi
    }

    if [ "$SAVE_TO_FILE" = "1" ]; then
      DEST="$OUT_FILE"
    else
      DEST=$(mktemp /tmp/angst-screenshot-XXXXXX.png)
      TMP_FILE="$DEST"
    fi

    case "$BACKEND" in
      maim) capture_maim "$DEST" ;;
      grim) capture_grim "$DEST" ;;
      portal) capture_portal "$DEST" ;;
      *) echo "Unknown backend: $BACKEND" >&2; exit 1 ;;
    esac

    if [ ! -f "$DEST" ]; then
      echo "Capture failed: $DEST not created" >&2
      exit 1
    fi

    if [ "$COPY_TO_CLIPBOARD" = "1" ]; then
      if [ -n "''${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
        wl-copy < "$DEST" || true
      elif command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard -t image/png -i "$DEST" || true
      elif command -v wl-copy >/dev/null 2>&1; then
        wl-copy < "$DEST" || true
      fi
    fi

    if command -v notify-send >/dev/null 2>&1; then
      if [ "$SAVE_TO_FILE" = "1" ]; then
        notify-send "Screenshot saved" "$DEST" -i "$DEST" 2>/dev/null || notify-send "Screenshot saved" "$DEST" 2>/dev/null || true
      else
        notify-send "Screenshot copied to clipboard" 2>/dev/null || true
      fi
    fi

    if [ "$SAVE_TO_FILE" = "1" ]; then
      echo "$DEST"
    else
      echo "Screenshot copied to clipboard (not saved)" >&2
    fi
  '';
}
