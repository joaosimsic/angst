{
  config,
  lib,
  pkgs,
  flakeSelf,
  userConfig,
  hostname,
  hostHostSecrets ? [ ],
  ...
}:

let
  parse =
    raw:
    let
      parts = lib.splitString "/" raw;
    in
    {
      scope = builtins.elemAt parts 0;
      name = builtins.elemAt parts 1;
    };

  entries = map parse hostHostSecrets;

  keyFile =
    entry:
    "/home/${userConfig.username}/.config/age/${
      if entry.scope == "work" then "work-keys.txt" else "keys.txt"
    }";

  decrypt =
    entry:
    let
      src = "${flakeSelf}/secrets/${entry.name}/${hostname}.age";
      dest = "/run/angst/host-secrets/${entry.name}";
    in
    ''
      if [ ! -f ${lib.escapeShellArg src} ]; then
        echo "warn: host secret ${entry.name} is not present at ${src}" >&2
      elif [ ! -f ${lib.escapeShellArg (keyFile entry)} ]; then
        echo "warn: no ${entry.scope} age key for host secret ${entry.name}" >&2
      elif { rm -f ${lib.escapeShellArg dest}; ${pkgs.age}/bin/age --decrypt \
        --identity ${lib.escapeShellArg (keyFile entry)} \
        --output ${lib.escapeShellArg dest} \
        ${lib.escapeShellArg src}; }; then
        chown "root:${config.users.users.${userConfig.username}.group}" ${lib.escapeShellArg dest}
        chmod 0640 ${lib.escapeShellArg dest}
      else
        rm -f ${lib.escapeShellArg dest}
        echo "warn: could not decrypt host secret ${entry.name}" >&2
      fi
    '';

  script = pkgs.writeShellScript "angst-provision-host-secrets" ''
    set -u
    umask 0027
    install -d -m 0750 -o root -g ${
      config.users.users.${userConfig.username}.group
    } /run/angst/host-secrets
    ${lib.concatMapStrings decrypt entries}
  '';
in
{
  config = lib.mkIf (hostHostSecrets != [ ]) {
    systemd.services.angst-provision-host-secrets = {
      description = "angst: decrypt declared host infrastructure secrets";
      wantedBy = [ "multi-user.target" ];
      after = [
        "local-fs.target"
        "vm-age-key.service"
      ];
      before = [ "tailscaled-autoconnect.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = script;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadOnlyPaths = [
          "/home/${userConfig.username}/.config/age"
        ]
        ++ map (entry: "${flakeSelf}/secrets/${entry.name}") (
          lib.filter (entry: builtins.pathExists (flakeSelf + "/secrets/${entry.name}")) entries
        );
        ReadWritePaths = [ "/run/angst" ];
        NoNewPrivileges = true;
        UMask = "0027";
        RestrictAddressFamilies = [ "AF_UNIX" ];
      };
    };
  };
}
