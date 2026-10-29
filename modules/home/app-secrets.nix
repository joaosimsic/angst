{
  lib,
  flakeSelf,
  runtime,
  hostScopes ? [ ],
  hostAppSecrets ? [ ],
  ...
}:

let
  enable = hostAppSecrets != [ ];

  secretsAppsDir = "${flakeSelf}/secrets/apps";

  scopesFlag = lib.concatStringsSep "," hostScopes;

  slugFlags = lib.concatMapStringsSep " " (s: "--slug ${lib.escapeShellArg s}") hostAppSecrets;
in
lib.mkIf enable {
  home.activation.angstAppSecrets = lib.hm.dag.entryAfter [ ] ''
    export HOME_MANAGER_BACKUP_EXT="hm-backup"
    ${runtime.goAngst}/bin/angst provision-app-secret \
      --home "$HOME" \
      --secrets-dir ${lib.escapeShellArg secretsAppsDir} \
      --scopes ${lib.escapeShellArg scopesFlag} \
      ${slugFlags} || true
  '';
}
