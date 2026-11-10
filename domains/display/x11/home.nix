{
  config,
  lib,
  pkgs,
  monitors,
  ...
}:

let
  cfg = config.domains.display.x11;

  nonPrimary = lib.filterAttrs (name: m: name != "primary" && m ? name) monitors;

  monitorOn =
    m:
    if (m.resolution or "auto") == "auto" then
      ''
        xrandr --output ${m.name} --auto --pos ${m.position or "1920x0"}
      ''
    else if (m.resolution or "auto") == "kernel" then
      ''
        res=""
        for arg in $(cat /proc/cmdline); do
          case "$arg" in
            video=${m.name}:*)
              res="''${arg#video=${m.name}:}"
              res="''${res%@*}"
              ;;
          esac
        done
        if [ -z "$res" ]; then
          echo "no kernel mode configured for ${m.name}" >&2
          exit 1
        fi
        xrandr --output ${m.name} --mode "$res" --rate ${toString (m.refreshRate or 60)} --pos ${m.position or "1920x0"}
      ''
    else
      ''
        xrandr --output ${m.name} --mode ${m.resolution} --rate ${toString (m.refreshRate or 60)} --pos ${m.position or "1920x0"}
      '';

  enableLines = lib.concatStrings (
    lib.mapAttrsToList (_: m: ''
      if xrandr --query | grep -qE "^${m.name} connected"; then
        ${monitorOn m}
      fi
    '') nonPrimary
  );

  disableLines = lib.concatStrings (
    lib.mapAttrsToList (_: m: ''
      xrandr --output ${m.name} --off 2>/dev/null || true
    '') nonPrimary
  );

  activeLines = lib.concatStrings (
    lib.mapAttrsToList (_: m: ''
      if xrandr --query | grep -qE "^${m.name} connected [0-9]"; then
        return 0
      fi
    '') nonPrimary
  );

  angstDisplay = pkgs.writeShellApplication {
    name = "angst-display";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.xrandr
      pkgs.gnugrep
    ];
    text = ''
      set -euo pipefail

      state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
      mode_file="$state_home/angst/display/mode"

      enable_all() {
        :
        ${enableLines}
      }

      disable_all() {
        :
        ${disableLines}
      }

      any_active() {
        ${activeLines}
        return 1
      }

      read_mode() {
        local fallback="''${1:-dual}"
        if [ -r "$mode_file" ]; then
          local saved
          saved=$(cat "$mode_file")
          case "$saved" in
            dual|stream)
              printf '%s\n' "$saved"
              return 0
              ;;
          esac
        fi
        printf '%s\n' "$fallback"
      }

      write_mode() {
        mkdir -p "$(dirname "$mode_file")"
        local tmp="$mode_file.tmp.$$"
        printf '%s\n' "$1" > "$tmp"
        mv "$tmp" "$mode_file"
      }

      apply_mode() {
        case "$1" in
          dual) enable_all ;;
          stream) disable_all ;;
          *)
            echo "unknown display mode: $1" >&2
            exit 2
            ;;
        esac
      }

      case "''${1:-toggle}" in
        stream|off)
          write_mode stream
          disable_all
          ;;
        dual|on)
          write_mode dual
          enable_all
          ;;
        toggle)
          if any_active; then
            write_mode stream
            disable_all
          else
            write_mode dual
            enable_all
          fi
          ;;
        apply)
          apply_mode "$(read_mode "''${2:-dual}")"
          ;;
        status)
          printf 'persisted: %s\n' "$(read_mode "''${2:-dual}")"
          if any_active; then
            echo "active: dual"
          else
            echo "active: stream"
          fi
          ;;
        *)
          echo "usage: angst-display [stream|dual|toggle|apply|status]" >&2
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
