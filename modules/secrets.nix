{ self, host, lib }:

let
  secretsFile =
    if host.domain != null then
      self + "/hosts/${host.domain}/${host.hostname}/secrets.yaml"
    else
      self + "/hosts/${host.hostname}/secrets.yaml";
  hasSecrets = builtins.pathExists secretsFile;
in
{
  inherit secretsFile hasSecrets;

  core = lib.mkIf hasSecrets {
    sops.defaultSopsFile = secretsFile;
    sops.secrets.masterPassword = { };
  };

  persistDirs = lib.optional hasSecrets ".config/sops";
}
