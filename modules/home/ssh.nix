{
  config,
  lib,
  ssh,
  ...
}:

let
  cfg = config.angst.ssh;

  includeLine = "Include ${config.home.homeDirectory}/.ssh/config.d/*";

  renderHost = h: ''
    Host ${h.host}
    ${lib.optionalString (h.hostName != null) "  HostName ${h.hostName}"}
    ${lib.optionalString (h.user != null) "  User ${h.user}"}
    ${lib.optionalString (h.identityFile != null) "  IdentityFile ${h.identityFile}"}
    ${lib.optionalString h.identitiesOnly "  IdentitiesOnly yes"}
  '';
in
{
  options.angst.ssh = {
    hosts = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            host = lib.mkOption {
              type = lib.types.str;
              description = "SSH Host alias or pattern";
            };

            hostName = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Actual hostname to connect to (defaults to Host)";
            };

            user = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "SSH user (e.g. \"git\" for GitLab)";
            };

            identityFile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Path to the private key to use for this host";
            };

            identitiesOnly = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Only use the configured identity for this host";
            };
          };
        }
      );
      default = ssh.hosts or [ ];
      description = "SSH host entries written to ~/.ssh/config.d/angst.conf";
    };
  };

  config = lib.mkIf (cfg.hosts != [ ]) {
    home.file.".ssh/config.d/angst.conf" = {
      text = lib.concatMapStrings renderHost cfg.hosts;
    };

    home.activation.ensureSshConfigInclude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/.ssh/config.d"
      $DRY_RUN_CMD chmod 700 "$HOME/.ssh" 2>/dev/null || true
      if [ ! -f "$HOME/.ssh/config" ]; then
        $DRY_RUN_CMD sh -c 'umask 077; printf "%s\n" "${includeLine}" > "$HOME/.ssh/config"'
      elif ! $DRY_RUN_CMD grep -qF "${includeLine}" "$HOME/.ssh/config"; then
        $VERBOSE_ECHO "angst: adding Include line to ~/.ssh/config"
        $DRY_RUN_CMD sh -c 'umask 077; printf "\n%s\n" "${includeLine}" >> "$HOME/.ssh/config"'
      fi
      $DRY_RUN_CMD chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
    '';
  };
}
