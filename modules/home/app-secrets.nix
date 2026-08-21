{
  lib,
  flakeSelf,
  runtime,
  hostScopes,
  hostSecrets,
  ...
}:

let
  enable = hostSecrets != [ ];

  secretsAppsDir = "${flakeSelf}/secrets/apps";

  scopesFlag = lib.concatStringsSep "," hostScopes;

  slugFlags = lib.concatMapStringsSep " " (s: "--slug ${lib.escapeShellArg s}") hostSecrets;
in
lib.mkIf enable {
  home.activation.angstAppSecrets = lib.hm.dag.entryAfter [ "sops-nix" "secrets-to-home" ] ''
    ${runtime.goAngst}/bin/angst provision-app-secret \
      --home "$HOME" \
      --secrets-dir ${lib.escapeShellArg secretsAppsDir} \
      --scopes ${lib.escapeShellArg scopesFlag} \
      ${slugFlags}
  '';
}
