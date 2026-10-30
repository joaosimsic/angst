{
  config,
  lib,
  pkgs,
  userConfig,
  ...
}:

let
  cfg = config.domains.chat.discord;
  inherit (userConfig) username;

  closeDiscord = pkgs.writeShellScript "discord-graceful-close" ''
    set -eu

    user=${lib.escapeShellArg username}
    ${lib.getExe' pkgs.procps "pgrep"} -u "$user" -f '/Discord' >/dev/null 2>&1 || exit 0

    xpid="$(${lib.getExe' pkgs.procps "pgrep"} -u "$user" -x X 2>/dev/null | ${lib.getExe' pkgs.coreutils "head"} -n1 || true)"
    [ -n "$xpid" ] || exit 0

    display=""
    xauth=""
    previous=""
    while IFS= read -r argument; do
      case "$argument" in
        :[0-9]*) display="$argument" ;;
      esac
      if [ "$previous" = "-auth" ]; then
        xauth="$argument"
      fi
      previous="$argument"
    done < <(${lib.getExe' pkgs.coreutils "tr"} '\0' '\n' < "/proc/$xpid/cmdline")

    [ -n "$display" ] || exit 0
    [ -n "$xauth" ] || xauth="/run/user/$(${lib.getExe' pkgs.coreutils "id"} -u "$user")/lyxauth"

    windows="$(${lib.getExe' pkgs.util-linux "runuser"} -u "$user" -- \
      ${lib.getExe' pkgs.coreutils "env"} DISPLAY="$display" XAUTHORITY="$xauth" \
      ${lib.getExe pkgs.xdotool} search --name ' - Discord$' 2>/dev/null || true)"
    [ -n "$windows" ] || windows="$(${lib.getExe' pkgs.util-linux "runuser"} -u "$user" -- \
      ${lib.getExe' pkgs.coreutils "env"} DISPLAY="$display" XAUTHORITY="$xauth" \
      ${lib.getExe pkgs.xdotool} search --class discord 2>/dev/null || true)"

    for window in $windows; do
      ${lib.getExe' pkgs.util-linux "runuser"} -u "$user" -- \
        ${lib.getExe' pkgs.coreutils "env"} DISPLAY="$display" XAUTHORITY="$xauth" \
        ${lib.getExe pkgs.xdotool} windowactivate --sync "$window" 2>/dev/null || true
      ${lib.getExe' pkgs.util-linux "runuser"} -u "$user" -- \
        ${lib.getExe' pkgs.coreutils "env"} DISPLAY="$display" XAUTHORITY="$xauth" \
        ${lib.getExe pkgs.xdotool} key --clearmodifiers ctrl+q 2>/dev/null || true
    done
    ${lib.getExe' pkgs.coreutils "sleep"} 2
  '';

  watchShutdown = pkgs.writeShellScript "discord-shutdown-watch" ''
    set -u

    ${lib.getExe' pkgs.coreutils "stdbuf"} -oL -eL \
      ${lib.getExe' pkgs.dbus "dbus-monitor"} --system \
      "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForShutdown'" |
      while IFS= read -r line; do
        case "$line" in
          *member=PrepareForShutdown*) shutdown=1 ;;
          *"boolean false"*) shutdown=0 ;;
          *"boolean true"*)
            if [ "''${shutdown:-0}" = 1 ]; then
              ${closeDiscord}
              exit 0
            fi
            ;;
        esac
      done
  '';
in
{
  options.domains.chat.discord.enable = lib.mkEnableOption "Discord session persistence hook";

  config = lib.mkIf cfg.enable {
    systemd.services.discord-shutdown-guard = {
      description = "angst: close Discord before shutdown so its session token is saved";
      wantedBy = [ "multi-user.target" ];
      wants = [ "dbus.service" ];
      after = [ "dbus.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe' pkgs.systemd "systemd-inhibit"} --what=shutdown --mode=delay --who=angst-discord --why=persist-discord-session ${watchShutdown}";
        Restart = "on-failure";
        RestartSec = 1;
      };
    };
  };
}
