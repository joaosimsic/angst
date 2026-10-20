{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.nix.cleanup;
  stamp = "/var/lib/angst/nix-cleanup.last";
  intervalSeconds = cfg.intervalDays * 24 * 60 * 60;

  cleanup = pkgs.writeShellScript "angst-nix-cleanup" ''
    set -eu
    stamp=${lib.escapeShellArg stamp}
    if [ -e "$stamp" ]; then
      last="$(${pkgs.coreutils}/bin/stat -c %Y "$stamp")"
      now="$(${pkgs.coreutils}/bin/date +%s)"
      if [ $((now - last)) -lt ${toString intervalSeconds} ]; then
        echo "angst: Nix cleanup not due yet"
        exit 0
      fi
    fi
    ${pkgs.nh}/bin/nh clean --elevation-strategy none all --keep ${toString cfg.keepGenerations}
    ${pkgs.coreutils}/bin/touch "$stamp"
  '';
in
{
  options.domains.nix.cleanup = {
    enable = lib.mkEnableOption "scheduled Nix cleanup";

    intervalDays = lib.mkOption {
      type = lib.types.ints.between 1 3650;
      default = 30;
      description = "Minimum days between cleanups.";
    };

    keepGenerations = lib.mkOption {
      type = lib.types.ints.between 1 100;
      default = 1;
      description = "Generations kept per profile.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.angst-nix-cleanup = {
      description = "angst: clean old Nix generations and store paths";
      after = [ "nix-daemon.socket" ];
      requires = [ "nix-daemon.socket" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = cleanup;
        StateDirectory = "angst";
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.angst-nix-cleanup = {
      wantedBy = [ "timers.target" ];

      timerConfig = {
        Unit = "angst-nix-cleanup.service";
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
