{
  config,
  lib,
  pkgs,
  host ? { },
  ...
}:

let
  cfg = config.domains.agents.opencode;
  muxEnabled = cfg.mux.enable;
  mux = import ./mux.nix {
    inherit config pkgs;
    opencodePackage = pkgs.opencode;
    portStart = cfg.mux.portStart;
    portEnd = cfg.mux.portEnd;
    idleTimeout = cfg.mux.idleTimeout;
  };
  opencode = import ./wrapper.nix {
    inherit pkgs lib;
    opencodePackage = pkgs.opencode;
    muxPackage = mux;
    inherit muxEnabled;
    muxFallback = cfg.mux.fallbackStandalone;
  };
  prune = import ./prune.nix {
    inherit pkgs;
    opencodePackage = pkgs.opencode;
    olderThanDays = cfg.prune.olderThanDays;
  };
in
{
  options.domains.agents.opencode.prune = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Auto-delete OpenCode sessions and sidecars older than olderThanDays.";
    };

    olderThanDays = lib.mkOption {
      type = lib.types.ints.between 1 3650;
      default = 7;
      description = "Age threshold for opencode-prune.";
    };
  };
  options.domains.agents.opencode.mux = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = builtins.elem "development" (host.profiles or [ ]);
      description = "Enable project-scoped shared OpenCode server. Enabled by the development profile.";
    };

    portStart = lib.mkOption {
      type = lib.types.port;
      default = 4200;
      description = "First TCP port considered for a project OpenCode server.";
    };

    portEnd = lib.mkOption {
      type = lib.types.port;
      default = 4899;
      description = "Last TCP port considered for a project OpenCode server.";
    };

    idleTimeout = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 900;
      description = "Seconds to keep a project server alive after its last attached TUI exits.";
    };

    fallbackStandalone = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run a standalone OpenCode TUI when the shared server cannot start.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !muxEnabled || cfg.mux.portStart <= cfg.mux.portEnd;
        message = "domains.agents.opencode.mux.portStart must be <= portEnd";
      }
    ];

    home.packages = [
      opencode
      pkgs.rtk
    ]
    ++ lib.optional muxEnabled mux
    ++ lib.optional cfg.prune.enable prune;

    xdg.configFile = (import ./skills.nix { inherit lib pkgs; }) // {
      "opencode/tui-plugins" = {
        source = ./config/tui-plugins;
        recursive = true;
      };
    };

    home.sessionVariables = {
      OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";
      OPENCODE_MUX = if muxEnabled then "1" else "0";
    };

    systemd = {
      user = {
        services = {
          "opencode-mux@" = lib.mkIf muxEnabled {
            Unit = {
              Description = "OpenCode project server (%i)";
            };
            Service = {
              Type = "simple";
              ExecStart = "${mux}/bin/opencode-mux server";
              EnvironmentFile = "%t/opencode-mux/%i/server.env";
              Restart = "on-failure";
              RestartSec = "2s";
              TimeoutStopSec = "10s";
            };
          };

          opencode-mux-reap = lib.mkIf muxEnabled {
            Unit = {
              Description = "Reap idle OpenCode project servers";
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${mux}/bin/opencode-mux reap";
            };
          };

          opencode-prune = lib.mkIf cfg.prune.enable {
            Unit = {
              Description = "Delete OpenCode sessions and sidecars older than ${toString cfg.prune.olderThanDays} days";
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${prune}/bin/opencode-prune";
            };
          };
        };

        timers.opencode-mux-reap = lib.mkIf muxEnabled {
          Unit = {
            Description = "Periodically reap idle OpenCode project servers";
          };
          Timer = {
            OnBootSec = "2min";
            OnUnitActiveSec = "2min";
            Unit = "opencode-mux-reap.service";
          };
          Install.WantedBy = [ "timers.target" ];
        };

        timers.opencode-prune = lib.mkIf cfg.prune.enable {
          Unit = {
            Description = "Daily OpenCode prune, with catch-up run at boot";
          };
          Timer = {
            OnCalendar = "daily";
            OnBootSec = "5min";
            Persistent = true;
            Unit = "opencode-prune.service";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    };
  };
}
