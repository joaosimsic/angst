{
  inputs,
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
    opencodeGoKey = {
      target = ".secrets/opencode-go-key";
      mode = "0600";
    };
  };

  masterPasswordDefs = lib.optionalAttrs (host.type == "nixos") {
    masterPassword = { };
  };

  mkCore =
    secretDefs:
    lib.mkIf canDecrypt {
      sops = {
        age.keyFile = "/home/${host.username}/.config/sops/age/keys.txt";
        defaultSopsFile = secretsFile;
        secrets = builtins.mapAttrs (_: _: { }) secretDefs;
      };
    };

  homeCore = mkCore (homeSecretDefs // masterPasswordDefs);
  systemCore = mkCore masterPasswordDefs;

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

  homeModules = [
    inputs.sops-nix.homeManagerModules.sops
    syncActivation
    homeCore
    (import ./home/secrets-activation.nix {
      secretDefs = homeSecretDefs;
    })
  ];
in
{
  inherit
    secretsFile
    hasSecrets
    canDecrypt
    homeSecretDefs
    homeCore
    systemCore
    homeModules
    ;

  persistDirs = lib.optional canDecrypt ".config/sops" ++ lib.optional canDecrypt ".secrets";
}
