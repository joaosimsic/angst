{
  self,
  host,
  lib,
}:

let
  masterAgePath = self + "/secrets/master/${host.hostname}.age";
  hasMasterAge = builtins.pathExists masterAgePath;

  hasAppSecrets = (host.secrets or [ ]) != [ ];
  hasDb = (host.db or [ ]) != [ ];

  appSecretsModule = import ./home/app-secrets.nix;
in
{
  inherit
    masterAgePath
    hasMasterAge
    ;

  canDecrypt = hasMasterAge;

  homeModules = lib.optionals hasAppSecrets [ appSecretsModule ];

  persistDirs =
    lib.optionals (hasMasterAge || hasAppSecrets || hasDb) [
      ".config/age"
      ".secrets"
    ]
    ++ lib.optionals hasDb [ ".secrets/db" ];
}
