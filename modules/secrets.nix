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
in
{
  inherit secretsFile hasSecrets canDecrypt;

  core = lib.mkIf canDecrypt {
    sops = {
      age.keyFile = "/home/${host.username}/.config/sops/age/keys.txt";
      defaultSopsFile = secretsFile;
      secrets = {
        opencodeGoKey = { };
      }
      // lib.optionalAttrs (host.type == "nixos") {
        masterPassword = { };
      };
    };
  };

  syncActivation =
    { config, lib, ... }:
    lib.mkIf canDecrypt {
      home.activation.secrets-ready = lib.hm.dag.entryAfter [ "sops-nix" ] ''
        ${config.systemd.user.systemctlPath} --user start --wait sops-nix.service
      '';
    };

  persistDirs = lib.optional canDecrypt ".config/sops";
}
