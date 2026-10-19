{
  config,
  lib,
  pkgs,
  db,
  flakeSelf,
  runtime,
  ...
}:

let
  sync = runtime.db-sync {
    inherit db flakeSelf;
  };
in
{
  config = lib.mkIf config.domains.sql-client.rainfrog.enable {
    home.packages = [ pkgs.rainfrog ];

    # Only define the activation/service if sqlit is not enabled to avoid duplicate.
    # If both clients are enabled, sqlit's activation already covers both configs
    # (angst db sync writes sqlit + rainfrog). This guard prevents duplicate units.
    home.activation.angstDbSyncRainfrog = lib.mkIf (!config.domains.sql-client.sqlit.enable) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "$HOME/.secrets/db" "$HOME/.config/sqlit" "$HOME/.config/rainfrog"
        chmod 700 "$HOME/.secrets" 2>/dev/null || true
        chmod 700 "$HOME/.secrets/db" 2>/dev/null || true
        ${sync.bin} import || true
        ${sync.bin} sync || true
      ''
    );

    systemd.user.services.angst-db-sync-rainfrog = lib.mkIf (!config.domains.sql-client.sqlit.enable) {
      Unit = {
        Description = "Sync DB credentials for rainfrog (vault)";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c '${sync.bin} import; ${sync.bin} sync'";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
