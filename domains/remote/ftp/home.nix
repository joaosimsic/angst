{
  config,
  lib,
  ftp,
  flakeSelf,
  runtime,
  userConfig,
  ...
}:

let
  cfg = config.angst.ftp;
  ftpEnabled = config.domains.remote.ftp.enable;

  secretPath =
    m:
    ".secrets/ftp/${lib.removeSuffix ".conf" (lib.removeSuffix ".age" (baseNameOf m.configFile))}.conf";

  secretsDecrypt = runtime.ftpSecretsHome {
    inherit (userConfig) homeDirectory;
    configs = map (m: {
      source = "${flakeSelf}/${m.configFile}";
      dest = secretPath m;
    }) cfg.mounts;
  };

  mountService =
    m:
    let
      name = lib.removeSuffix ".conf" (lib.removeSuffix ".age" (baseNameOf m.configFile));
      mount = runtime.ftpMount {
        inherit (m) mountPoint;
        configFile = secretPath m;
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
              description = "Path (repo-relative) of the work-key-encrypted rclone config, decrypted into ~/.secrets/ftp at home activation";
            };
          };
        }
      );
      default = ftp.mounts or [ ];
      description = "FTP mounts: each entry decrypts a work-key rclone config into ~/.secrets/ftp and mounts it with rclone";
    };
  };

  config = lib.mkIf (ftpEnabled && cfg.mounts != [ ]) {
    home.activation.ensureFtpMountDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      rmdir "$HOME/secrets/angst" "$HOME/secrets" 2>/dev/null || true
      ${lib.concatMapStringsSep "\n" (m: ''
        mkdir -p "$HOME/${m.mountPoint}"
      '') cfg.mounts}
    '';

    home.activation.angstFtpSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${secretsDecrypt.bin}
    '';

    systemd.user.services = lib.listToAttrs (map mountService cfg.mounts);
  };
}
