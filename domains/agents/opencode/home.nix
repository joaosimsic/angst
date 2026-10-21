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
    inherit config lib pkgs;
    opencodePackage = pkgs.opencode;
    portStart = cfg.mux.portStart;
    portEnd = cfg.mux.portEnd;
    idleTimeout = cfg.mux.idleTimeout;
  };
  opencode = import ./wrapper.nix {
    inherit pkgs lib;
    opencodePackage = pkgs.opencode;
    muxPackage = mux;
    muxEnabled = muxEnabled;
    muxFallback = cfg.mux.fallbackStandalone;
  };
in
{
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
    ++ lib.optional muxEnabled mux;

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

    systemd.user.services."opencode-mux@" = lib.mkIf muxEnabled {
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

    systemd.user.services.opencode-mux-reap = lib.mkIf muxEnabled {
      Unit = {
        Description = "Reap idle OpenCode project servers";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${mux}/bin/opencode-mux reap";
      };
    };

    systemd.user.timers.opencode-mux-reap = lib.mkIf muxEnabled {
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
  };
}
