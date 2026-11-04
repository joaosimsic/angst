{
  config,
  lib,
  pkgs,
  monitors,
  ...
}:

let
  cfg = config.domains.display.x11;
  secondary = monitors.secondary or null;

  secondaryOn =
    if secondary == null then
      ''
        echo "no secondary monitor configured" >&2
        exit 1
      ''
    else if (secondary.resolution or "auto") == "auto" then
      ''
        xrandr --output "$secondary" --auto --pos ${secondary.position or "1920x0"}
      ''
    else if (secondary.resolution or "auto") == "kernel" then
      ''
        res=""
        for arg in $(cat /proc/cmdline); do
          case "$arg" in
            video=${secondary.name}:*)
              res="''${arg#video=${secondary.name}:}"
              res="''${res%@*}"
              ;;
          esac
        done
        if [ -z "$res" ]; then
          echo "no kernel mode configured for $secondary" >&2
          exit 1
        fi
        xrandr --output "$secondary" --mode "$res" --rate ${
          toString (secondary.refreshRate or 60)
        } --pos ${secondary.position or "1920x0"}
      ''
    else
      ''
        xrandr --output "$secondary" --mode ${secondary.resolution} --rate ${
          toString (secondary.refreshRate or 60)
        } --pos ${secondary.position or "1920x0"}
      '';

  angstDisplay = pkgs.writeShellApplication {
    name = "angst-display";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.xrandr
      pkgs.gnugrep
    ];
    text = ''
      set -euo pipefail

      secondary=${lib.escapeShellArg (secondary.name or "")}
      if [ -z "$secondary" ]; then
        echo "no secondary monitor configured" >&2
        exit 1
      fi

      is_active() {
        xrandr --query | grep -qE "^$secondary connected [0-9]"
      }

      on() {
        ${secondaryOn}
      }

      off() {
        xrandr --output "$secondary" --off
      }

      case "''${1:-toggle}" in
        on) on ;;
        off) off ;;
        toggle)
          if is_active; then
            off
          else
            on
          fi
          ;;
        *)
          echo "usage: angst-display [on|off|toggle]" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || config.domains.kernel.graphical.enable;
          message = "domains.display.x11 requires domains.kernel.graphical to be enabled";
        }
      ];
    }
    (lib.mkIf cfg.enable {
      home.packages = with pkgs; [
        hsetroot
        angstDisplay
      ];
    })
  ];
}
