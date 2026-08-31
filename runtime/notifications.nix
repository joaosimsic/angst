{
  mkScript,
  pkgs,
}:
{
  backend,
  name,
}:
mkScript {
  inherit name;
  runtimeInputs = with pkgs; [ libnotify dunst mako dbus coreutils ];
  text = ''
    set -euo pipefail

    BACKEND_CFG="${backend}"
    BACKEND="''${ANGST_NOTIFICATION_BACKEND:-$BACKEND_CFG}"

    if [ "$BACKEND" = "auto" ]; then
      if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
        BACKEND="mako"
      else
        BACKEND="dunst"
      fi
    fi

    ACTION="''${1:-dismiss}"
    case "$ACTION" in
      dismiss|close)
        case "$BACKEND" in
          dunst) exec dunstctl close 2>/dev/null || true ;;
          mako) exec makoctl dismiss 2>/dev/null || true ;;
          *) exec notify-send "dismiss" 2>/dev/null || true ;;
        esac
        ;;
      dismiss-all|close-all)
        case "$BACKEND" in
          dunst) exec dunstctl close-all 2>/dev/null || true ;;
          mako) exec makoctl dismiss --all 2>/dev/null || makoctl dismiss -a 2>/dev/null || true ;;
          *) true ;;
        esac
        ;;
      history|restore)
        case "$BACKEND" in
          dunst) exec dunstctl history-pop 2>/dev/null || true ;;
          mako) exec makoctl restore 2>/dev/null || true ;;
          *) true ;;
        esac
        ;;
      notify|send)
        shift || true
        TITLE="''${1:-Notification}"
        BODY="''${2:-}"
        ICON="''${3:-}"
        if [ -n "$ICON" ]; then
          if [ -n "$BODY" ]; then
            exec notify-send -i "$ICON" "$TITLE" "$BODY" 2>/dev/null || true
          else
            exec notify-send -i "$ICON" "$TITLE" 2>/dev/null || true
          fi
        else
          if [ -n "$BODY" ]; then
            exec notify-send "$TITLE" "$BODY" 2>/dev/null || true
          else
            exec notify-send "$TITLE" 2>/dev/null || true
          fi
        fi
        ;;
      *) echo "Usage: $0 [dismiss|dismiss-all|history|notify <title> [body]]" >&2; exit 1 ;;
    esac
  '';
}
