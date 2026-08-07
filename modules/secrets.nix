{ self, host, lib }:

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
      keyFile = "${home}/.config/sops/age/keys.txt";
      keyFileCheck = builtins.tryEval (builtins.readFile keyFile);
      sopsKeyEnv = builtins.getEnv "SOPS_AGE_KEY";
      sopsKeyFileEnv = builtins.getEnv "SOPS_AGE_KEY_FILE";
    in
      (sopsKeyEnv != "") || (sopsKeyFileEnv != "") || keyFileCheck.success;

  canDecrypt = hasSecrets && hasAgeKey;
in
{
  inherit secretsFile hasSecrets canDecrypt;

  core = lib.mkIf canDecrypt {
    sops.defaultSopsFile = secretsFile;
    sops.secrets.masterPassword = { };
  };

  persistDirs = lib.optional canDecrypt ".config/sops";
}
