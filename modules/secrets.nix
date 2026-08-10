{
  self,
  host,
  lib,
}:

let
  secretsFile =
    if host.domain != null then
      self + "/hosts/${host.domain}/${host.hostname}/secrets.yaml"
    else
      self + "/hosts/${host.hostname}/secrets.yaml";
  hasSecrets = builtins.pathExists secretsFile;

  hasAgeKey =
    let
      home = builtins.getEnv "HOME";
      sopsKeyEnv = builtins.getEnv "SOPS_AGE_KEY";
      sopsKeyFileEnv = builtins.getEnv "SOPS_AGE_KEY_FILE";
      keyOk =
        if home != "" then
          let
            k = builtins.tryEval (builtins.pathExists "${home}/.config/sops/age/keys.txt");
          in
          k.success && k.value
        else
          false;
    in
    (sopsKeyEnv != "") || (sopsKeyFileEnv != "") || keyOk;

  canDecrypt = hasSecrets && hasAgeKey;

  homeSecretDefs = {
    opencodeGoKey = { target = ".secrets/opencode-go-key"; mode = "0600"; };
  };
in
{
  inherit secretsFile hasSecrets canDecrypt homeSecretDefs;

  core = lib.mkIf canDecrypt {
    sops = {
      age.keyFile = "/home/${host.username}/.config/sops/age/keys.txt";
      defaultSopsFile = secretsFile;
      secrets = builtins.mapAttrs (_: _: { }) homeSecretDefs
        // lib.optionalAttrs (host.type == "nixos") {
          masterPassword = { };
        };
    };
  };

  syncActivation =
    { config, lib, ... }:
    lib.mkIf canDecrypt {
      home.activation.secrets-ready = lib.hm.dag.entryAfter [ "sops-nix" ] ''
        systemdStatus=$(${config.systemd.user.systemctlPath} --user is-system-running 2>&1 || true)
        if [[ $systemdStatus == "running" || $systemdStatus == "degraded" ]]; then
          ${config.systemd.user.systemctlPath} --user start --wait sops-nix.service
        fi
      '';
    };

  persistDirs = lib.optional canDecrypt ".config/sops" ++ lib.optional canDecrypt ".secrets";
}
