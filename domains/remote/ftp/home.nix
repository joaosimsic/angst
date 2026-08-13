{
  config,
  lib,
  ftp,
  flakeSelf,
  runtime,
  ...
}:

let
  cfg = config.angst.ftp;
  ftpEnabled = config.domains.remote.ftp.enable;

  installPath = m:
    "secrets/angst/${lib.removeSuffix ".age" (baseNameOf m.configFile)}.age";

  mountService = m:
    let
      name = lib.removeSuffix ".conf" (lib.removeSuffix ".age" (baseNameOf m.configFile));
      mount = runtime.ftpMount {
        inherit (m) mountPoint;
        configFile = installPath m;
      };
    in
    lib.nameValuePair "angst-ftp-${name}" {
      Unit = {
        Description = "Mount FTP server at ${m.mountPoint}";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${mount.bin} mount";
        Restart = "on-failure";
        RestartSec = "10s";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
in
{
  options.angst.ftp = {
    mounts = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            mountPoint = lib.mkOption {
              type = lib.types.str;
              description = "Local directory where the FTP server is mounted (must not reveal the server name)";
            };

            configFile = lib.mkOption {
              type = lib.types.str;
              default = "secrets/ftp/ftp-server.conf.age";
              description = "Path (repo-relative) of the work-key-encrypted rclone config, installed at build time";
            };
          };
        }
      );
      default = ftp.mounts or [ ];
      description = "FTP mounts: each entry installs a work-key rclone config at build time and mounts it with rclone";
    };
  };

  config = lib.mkIf (ftpEnabled && cfg.mounts != [ ]) {
    home.file = lib.listToAttrs (
      map (m: {
        name = installPath m;
        value = {
          text = builtins.readFile "${flakeSelf}/${m.configFile}";
        };
      }) cfg.mounts
    );

    home.activation.ensureFtpMountDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${lib.concatMapStringsSep "\n" (
        m: ''
          mkdir -p "$HOME/${m.mountPoint}"
          chmod 600 "$HOME/${installPath m}" 2>/dev/null || true
        ''
      ) cfg.mounts}
    '';

    systemd.user.services = lib.listToAttrs (map mountService cfg.mounts);
  };
}
